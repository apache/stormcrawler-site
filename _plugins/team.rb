# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'json'
require 'net/http'
require 'uri'
require 'time'
require 'digest'
require 'fileutils'
require 'set'

# Populates `site.data['team']` and `site.data['wall_of_fame']` at build time.
#
# Team roster comes from the Apache Whimsy LDAP exports:
#   https://whimsy.apache.org/public/public_ldap_projects.json
#     -> projects.<key>.members  = committers
#     -> projects.<key>.owners   = PMC members
#   https://whimsy.apache.org/public/public_ldap_people.json
#     -> people.<id>.name + githubUsername
#
# Wall of Fame comes from GitHub's /contributors endpoint, aggregated across
# the configured repos and filtered to exclude PMC + committers + bots.
#
# Manual overrides come from `_data/team_overrides.yml` (chair flag, GH login).
#
# Set `JEKYLL_TEAM_NO_FETCH=1` to skip the network and reuse on-disk cache.
module StormcrawlerTeam
  PROJECTS_URL = 'https://whimsy.apache.org/public/public_ldap_projects.json'.freeze
  PEOPLE_URL   = 'https://whimsy.apache.org/public/public_ldap_people.json'.freeze
  GITHUB_API   = 'https://api.github.com'.freeze
  CACHE_TTL    = 6 * 60 * 60

  PALETTE = %w[
    #3a1c71 #6a3093 #1f4068 #2c5364 #283c86 #0f2027
    #5614b0 #11324d #16222a #373b44 #1d2671 #3b1f5b
  ].freeze

  BOT_LOGINS = %w[
    dependabot[bot] github-actions[bot] actions-user buildbot
    renovate[bot] codecov-commenter copilot copilot-swe-agent[bot]
  ].map(&:downcase).to_set.freeze

  class Generator < Jekyll::Generator
    safe false
    priority :high

    def generate(site)
      cfg          = site.config['team'] || {}
      project_key  = cfg['whimsy_project'] || 'stormcrawler'
      repos        = cfg['repos'] || %w[apache/incubator-stormcrawler apache/incubator-stormcrawler-site]
      cache_dir    = File.join(site.source, '.jekyll-cache', 'team')
      FileUtils.mkdir_p(cache_dir)
      no_fetch     = %w[1 true yes].include?((ENV['JEKYLL_TEAM_NO_FETCH'] || '').downcase)

      projects_json = fetch_json(PROJECTS_URL, File.join(cache_dir, 'projects.json'), no_fetch)
      people_json   = fetch_json(PEOPLE_URL,   File.join(cache_dir, 'people.json'),   no_fetch)
      overrides     = site.data['team_overrides'] || {}

      # Pull GitHub contributor data once: drives both gh-login auto-discovery
      # for the team list and the wall-of-fame aggregation.
      contributor_rows = repos.flat_map { |r| fetch_contributors(r, cache_dir, no_fetch) }
      contributor_login_index = {} # login.downcase -> original-cased login
      contributor_rows.each do |r|
        login = r['login']
        next if login.nil? || login.to_s.strip.empty?
        contributor_login_index[login.downcase] ||= login
      end

      members = build_members(projects_json, people_json, project_key, overrides, contributor_login_index)
      members.sort_by! { |m| sort_key(m['name']) }
      site.data['team'] = members

      excluded = excluded_logins(members)
      wall = build_wall_of_fame(contributor_rows, cache_dir, no_fetch, excluded)
      site.data['wall_of_fame'] = wall

      site.data['team_meta'] = {
        'last_updated'        => Time.now.utc.strftime('%Y-%m-%d %H:%M UTC'),
        'project_key'         => project_key,
        'count'               => members.size,
        'wall_of_fame_count'  => wall.size,
        'repos'               => repos
      }
      Jekyll.logger.info 'Team:',
        "#{members.size} member(s), wall-of-fame: #{wall.size} for project '#{project_key}'"
    end

    private

    # ---- Whimsy roster ------------------------------------------------------

    def build_members(projects, people, key, overrides, contributor_login_index)
      return [] unless projects && projects['projects'] && projects['projects'][key]

      project    = projects['projects'][key]
      committers = Array(project['members'])
      pmc        = Array(project['owners'])
      ids        = (committers + pmc).uniq.sort

      people_map = (people && people['people']) || {}

      ids.map do |id|
        info = people_map[id] || {}
        ov   = overrides[id] || {}
        name = ov['name'] || info['name'] || id

        # `gh` override may be a list (`[a, b]` or `"a;b"`) for committers with
        # multiple GitHub accounts; the first entry is the primary used for the
        # profile link, the rest are aliases that get excluded from the Wall of
        # Fame so the same person isn't listed twice.
        gh_list = parse_gh_list(ov['gh'])
        if gh_list.empty?
          single = info['githubUsername'] || gh_from_urls(info['urls'])
          gh_list = [single] if single && !single.to_s.strip.empty?
        end
        if gh_list.empty? && contributor_login_index.key?(id.downcase)
          gh_list = [contributor_login_index[id.downcase]]
        end

        gh           = gh_list.first
        gh_aliases   = gh_list.drop(1)
        is_pmc       = pmc.include?(id)
        is_committer = committers.include?(id) || is_pmc
        is_chair     = ov['chair'] == true
        gh_present   = gh && !gh.to_s.strip.empty?

        {
          'name'        => name,
          'apache_id'   => id,
          'gh'          => gh_present ? gh : nil,
          'gh_aliases'  => gh_aliases,
          'pmc'         => is_pmc,
          'committer'   => is_committer,
          'chair'       => is_chair,
          'role_flags'  => role_flags(is_committer, is_pmc),
          'profile_url' => gh_present ? "https://github.com/#{gh}" : nil,
          'initials'    => initials(name),
          'color'       => PALETTE[name.hash.abs % PALETTE.size]
        }
      end
    end

    def parse_gh_list(value)
      return [] if value.nil?
      list = value.is_a?(Array) ? value : value.to_s.split(/[;,]/)
      list.map { |v| v.to_s.strip }.reject(&:empty?)
    end

    def role_flags(committer, pmc)
      return 'C-P' if committer && pmc
      return 'P'   if pmc
      return 'C'   if committer
      ''
    end

    def initials(name)
      parts = name.to_s.strip.split(/\s+/)
      return name.to_s.upcase if parts.empty?
      return (parts.first[0].to_s + parts.last[0].to_s).upcase if parts.size >= 2
      parts.first[0, 2].to_s.upcase
    end

    def sort_key(name)
      parts = name.to_s.strip.split(/\s+/)
      return name.to_s.downcase if parts.size < 2
      "#{parts.last}, #{parts.first}".downcase
    end

    def gh_from_urls(urls)
      return nil unless urls.is_a?(Array)
      urls.each do |u|
        if u =~ %r{https://github\.com/([^/?#]+)}
          return Regexp.last_match(1)
        end
      end
      nil
    end

    # ---- Wall of Fame -------------------------------------------------------

    def excluded_logins(members)
      out = Set.new
      members.each do |m|
        out << m['gh'].downcase        if m['gh']
        out << m['apache_id'].downcase if m['apache_id']
        Array(m['gh_aliases']).each { |a| out << a.downcase }
      end
      out
    end

    def bot?(login)
      lower = login.to_s.downcase
      lower.end_with?('[bot]') || BOT_LOGINS.include?(lower)
    end

    def build_wall_of_fame(contributor_rows, cache_dir, no_fetch, excluded)
      acc = {}
      contributor_rows.each do |r|
        login = r['login']
        next if login.nil? || login.to_s.strip.empty?
        next if bot?(login)
        next if excluded.include?(login.downcase)

        key = login.downcase
        rec = acc[key] ||= { 'login' => login, 'commits' => 0 }
        rec['commits'] += (r['contributions'] || 0).to_i
      end

      # Sort by commit count for ordering only; the count is not rendered.
      list = acc.values.sort_by { |r| [-r['commits'], r['login'].downcase] }
      list.each do |rec|
        name = fetch_user_name(rec['login'], cache_dir, no_fetch) || rec['login']
        rec['name']        = name
        rec['profile_url'] = "https://github.com/#{rec['login']}"
        rec['initials']    = initials(name)
        rec['color']       = PALETTE[name.hash.abs % PALETTE.size]
      end
      list
    end

    def fetch_contributors(repo, cache_dir, no_fetch)
      out = []
      url = "#{GITHUB_API}/repos/#{repo}/contributors?per_page=100&anon=0"
      page = 1
      cache_id = repo.gsub('/', '_')
      loop do
        cache_path = File.join(cache_dir, "gh_contrib_#{cache_id}_p#{page}.json")
        body, link = github_get_cached(url, cache_path, no_fetch)
        break unless body

        begin
          arr = JSON.parse(body)
        rescue JSON::ParserError => e
          Jekyll.logger.warn 'Team:', "wall-of-fame parse failed for #{repo} p#{page}: #{e.message}"
          break
        end
        break unless arr.is_a?(Array)
        arr.each { |c| out << c if c.is_a?(Hash) }
        nxt = parse_next_link(link)
        break unless nxt
        url = nxt
        page += 1
      end
      out
    rescue StandardError => e
      Jekyll.logger.warn 'Team:', "wall-of-fame fetch failed for #{repo}: #{e.message}"
      []
    end

    def fetch_user_name(login, cache_dir, no_fetch)
      cache_path = File.join(cache_dir, "gh_user_#{login.downcase}.json")
      body, _link = github_get_cached("#{GITHUB_API}/users/#{login}", cache_path, no_fetch)
      return nil unless body
      obj = JSON.parse(body)
      n = obj['name']
      n && !n.to_s.strip.empty? ? n : nil
    rescue StandardError
      nil
    end

    # GitHub fetch with on-disk cache + sidecar Link-header file. Returns [body, link]
    # or [nil, nil] when there is neither a fresh cache nor a successful fetch.
    def github_get_cached(url, cache_path, no_fetch)
      link_path = cache_path + '.link'
      if File.exist?(cache_path) && (no_fetch || (Time.now - File.mtime(cache_path)) < CACHE_TTL)
        body = File.read(cache_path)
        link = File.exist?(link_path) ? File.read(link_path) : nil
        return [body, link]
      end
      return [nil, nil] if no_fetch

      body, link = github_get(url)
      File.write(cache_path, body)
      File.write(link_path, link.to_s)
      [body, link]
    rescue StandardError => e
      Jekyll.logger.warn 'Team:', "GitHub GET #{url} failed: #{e.message}"
      if File.exist?(cache_path)
        [File.read(cache_path), File.exist?(link_path) ? File.read(link_path) : nil]
      else
        [nil, nil]
      end
    end

    def github_get(url, limit = 5)
      raise 'too many redirects' if limit <= 0
      uri = URI.parse(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                      open_timeout: 10, read_timeout: 30) do |http|
        req = Net::HTTP::Get.new(uri.request_uri,
                                 'User-Agent' => 'stormcrawler-site-jekyll-plugin',
                                 'Accept'     => 'application/vnd.github+json')
        token = ENV['GITHUB_TOKEN']
        req['Authorization'] = "Bearer #{token}" if token && !token.empty?
        res = http.request(req)
        case res
        when Net::HTTPSuccess     then [res.body, res['Link']]
        when Net::HTTPRedirection then github_get(res['location'], limit - 1)
        else raise "HTTP #{res.code} for #{url}"
        end
      end
    end

    def parse_next_link(link_header)
      return nil if link_header.nil? || link_header.empty?
      link_header.split(',').each do |part|
        if part =~ /<([^>]+)>;\s*rel="next"/
          return Regexp.last_match(1)
        end
      end
      nil
    end

    # ---- Whimsy fetch -------------------------------------------------------

    def fetch_json(url, cache_path, no_fetch)
      if no_fetch
        return load_cache(cache_path) || (Jekyll.logger.warn('Team:', "no-fetch and no cache for #{url}"); nil)
      end

      if File.exist?(cache_path) && (Time.now - File.mtime(cache_path)) < CACHE_TTL
        cached = load_cache(cache_path)
        return cached if cached
      end

      begin
        body = http_get(url)
        File.write(cache_path, body)
        JSON.parse(body)
      rescue StandardError => e
        Jekyll.logger.warn 'Team:', "fetch failed for #{url}: #{e.message}"
        load_cache(cache_path)
      end
    end

    def load_cache(path)
      return nil unless File.exist?(path)
      JSON.parse(File.read(path))
    rescue StandardError
      nil
    end

    def http_get(url, limit = 5)
      raise 'too many redirects' if limit <= 0
      uri = URI.parse(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                      open_timeout: 10, read_timeout: 30) do |http|
        req = Net::HTTP::Get.new(uri.request_uri,
                                 'User-Agent' => 'stormcrawler-site-jekyll-plugin',
                                 'Accept'     => 'application/json')
        res = http.request(req)
        case res
        when Net::HTTPSuccess     then res.body
        when Net::HTTPRedirection then http_get(res['location'], limit - 1)
        else raise "HTTP #{res.code} for #{url}"
        end
      end
    end
  end
end
