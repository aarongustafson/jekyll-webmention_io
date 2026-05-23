# frozen_string_literal: true

require 'uri'

module Jekyll
  module WebmentionIO
    class Config
      module HtmlProofer
        NONE = 'none'
        ALL = 'all'
        TEMPLATES = 'templates'

        def self.get_const(val)
          constants.find { |sym| const_get(sym) == val }
        end
      end

      module UriPolicy
        BAN = 'ban'
        IGNORE = 'ignore'
        RETRY = 'retry'
      end

      TIMEFRAMES = {
        'last_week' => 'weekly',
        'last_month' => 'monthly',
        'last_year' => 'yearly',
      }.freeze

      attr_accessor :html_proofer_ignore, :max_attempts,
                    :templates, :bad_uri_policy, :throttle_lookups, :cache_folder,
                    :legacy_domains, :pause_lookups, :site_url, :syndication, :js,
                    :username, :debug, :api_url

      # The scheme://host[:port] origin and bare host of the configured API,
      # derived from api_url. Used to build the service links emitted into the
      # page head (and the JS) so they track a custom endpoint instead of being
      # hard-coded to webmention.io.
      attr_reader :api_origin, :api_host

      # The default base URL for the Webmention.io API. Exposed as a config key
      # so the endpoint can be pointed elsewhere (e.g. a local stand-in during
      # integration testing) instead of being hard-coded in the network layer.
      DEFAULT_API_URL = 'https://webmention.io/api'

      # Resolves a webmention API URL to a URI, falling back to the default
      # endpoint when the configured value has no host.
      def self.api_uri(url)
        uri = URI.parse(url)
        uri.host ? uri : URI.parse(DEFAULT_API_URL)
      end

      # The host of a parsed API URI, plus the port when it isn't the scheme's
      # default (so custom/local endpoints still match the full URL).
      def self.authority(uri)
        uri.port == uri.default_port ? uri.host : "#{uri.host}:#{uri.port}"
      end

      def initialize(site = nil)
        @site = site

        if site.nil?
          parse
        else
          parse(@site.config['webmentions'], @site.config['url'].to_s, @site.config['baseurl'].to_s)
        end
      end

      def parse(config = nil, site_url = '', base_url = '')
        config ||= {}

        @site_url = site_url
        @username = config['username']
        @debug = config['debug']
        @api_url = config['api_url'] || DEFAULT_API_URL
        api_uri = self.class.api_uri(@api_url)
        @api_host = api_uri.host
        @api_origin = "#{api_uri.scheme}://#{self.class.authority(api_uri)}"

        @pause_lookups =
          if !@site.nil? && @site.config['serving']
            WebmentionIO.log 'msg', 'Webmentions won’t be gathered when running `jekyll serve`.'

            true
          elsif !@site.nil? && @site_url.include?('localhost')
            WebmentionIO.log 'msg', 'Webmentions won’t be gathered on localhost.'

            true
          else
            config['pause_lookups']
          end

        @cache_folder = config['cache_folder'] || '.jekyll-cache'
        @cache_folder = @site.in_source_dir(@cache_folder) if !@site.nil?

        @pages = config['pages']
        @collections = config['collections'] || {}
        @templates = config['templates'] || {}

        @js = JsConfig.new(base_url, config['js'] || false)

        @html_proofer_ignore = HtmlProofer.get_const(
          config['html_proofer_ignore'] ||
          (config['html_proofer'] ? 'templates' : nil) ||
          'none'
        )

        @max_attempts = config['max_attempts']

        @bad_uri_policy = BadUriPolicy.new(config)

        @throttle_lookups = config['throttle_lookups'] || {}

        @legacy_domains = config['legacy_domains'] || []

        @syndication = (config['syndication'] || {}).transform_values { |entry| SyndicationRule.new(entry) }
      end

      # The next lookup date has to be before this date to be allowed to
      # request webmentions again.
      def last_lookup_threshold(date)
        age = get_timeframe_from_date(date)

        throttle = @throttle_lookups[age]

        throttle.nil? ? nil : get_date_from_string(throttle)
      end

      # Given a webmention endpoint, find the corresponding syndication rule
      # Yes, this is a kind of reverse lookup so we can figure out of a given
      # queued webmention was a result of a syndication rule.
      def syndication_rule_for_uri(uri)
        @syndication.values.detect { |rule| rule.endpoint == uri }
      end

      # Based on the specified configuration, return the list of documents for
      # the site that should be processed.
      def documents
        documents = @site.posts.docs.clone

        if @pages == true
          WebmentionIO.log 'info', 'Including site pages.'
          documents.concat @site.pages.clone
        end

        if @collections.empty?
          WebmentionIO.log 'info', 'Adding collections.'

          @site.collections.each do |name, collection|
            # skip _posts
            next if name == 'posts'

            if collections.include?(name)
              documents.concat collection.docs.clone
            end
          end
        end

        documents
      end

      def collections
        @site.collections
      end

      class BadUriPolicy
        BadUriPolicyEntry = Struct.new(:policy, :max_attempts, :retry_delay)

        attr_reader :whitelist, :blacklist

        def initialize(site_config)
          @bad_uri_policy = site_config['bad_uri_policy'] || {}

          @bad_uri_policy['whitelist'] ||= []
          @bad_uri_policy['blacklist'] ||= []

          # We always want to collect webmentions from the configured API host,
          # so we explicitly whitelist it. This way a transient service outage
          # won't get the endpoint banned by the bad-URI policy. Derived from the
          # configured api_url (default webmention.io) so a custom endpoint gets
          # the same protection.
          @bad_uri_policy['whitelist'].insert(-1, api_host_pattern(site_config))

          @whitelist = @bad_uri_policy['whitelist'].map { |expr| Regexp.new(expr) }
          @blacklist = @bad_uri_policy['blacklist'].map { |expr| Regexp.new(expr) }
        end

        def set_policy(state, policy, max_attempts = nil, retry_delay = nil)
          @bad_uri_policy[state] = {
            'policy' => policy,
            'max_attempts' => max_attempts,
            'retry_delay' => retry_delay
          }
        end

        # Given the provided state value (see WebmentionPolicy::State),
        # retrieve the policy entry.  If no entry exists, return a new default
        # entry that indicates unlimited retries.
        def for_state(state)
          default_policy = { 'policy' => UriPolicy::RETRY }

          # Retrieve the policy entry, the default entry, or the canned default
          policy_entry = @bad_uri_policy[state] || @bad_uri_policy['default'] || default_policy

          # Convert shorthand entry to full policy record
          if policy_entry.instance_of? String
            policy_entry = { 'policy' => policy_entry }
          end

          if policy_entry['policy'] == UriPolicy::RETRY && !policy_entry.key?('retry_delay')
            # If this is a retry policy and no delay is set, set up the default
            # delay policy.  This inherits from the legacy cache_bad_uris_for
            # setting to enable backward compatibility with older configurations.
            #
            # We do this here to make the rule enforcement logic a little tidier.

            policy_entry['retry_delay'] = [(@bad_uri_policy['cache_bad_uris_for'] || 1) * 24]
          end

          # Now finally convert into a proper policy entry structure
          BadUriPolicyEntry.new(
            policy_entry['policy'],
            policy_entry['max_attempts'],
            policy_entry['retry_delay']
          )
        end

        private

        # Builds an anchored host pattern for the configured webmention API so it
        # is always exempt from the bad-URI policy, mirroring the api_url read in
        # Config#parse. A non-default port is included so custom/local endpoints
        # still match the full URL the network layer checks.
        def api_host_pattern(site_config)
          uri = Config.api_uri(site_config['api_url'] || DEFAULT_API_URL)
          "^https?://#{Regexp.escape(Config.authority(uri))}/"
        end
      end

      class SyndicationRule
        attr_reader :endpoint, :response_mapping, :shorturl, :fragment

        def initialize(entry)
          @endpoint = entry['endpoint']
          @shorturl = entry['shorturl']
          @fragment = entry['fragment']
          @response_mapping = {}

          return unless entry.key?('response_mapping')

          entry['response_mapping'].each do |key, pattern|
            @response_mapping[key] = JsonPath.new(pattern)
          rescue StandardError => e
            WebmentionIO.log 'error', "Ignoring invalid JsonPath expression #{pattern}: #{e}"
          end
        end
      end

      class JsConfig
        attr_reader :destination, :resource_name, :resource_url

        def initialize(base_url, js_config)
          if js_config == false
            @disabled = true
            return
          end

          @disabled = false
          @destination = js_config['destination'] || 'js'

          # rubocop:disable Style/RedundantCondition
          # Apparently this cop is broken...
          @deploy = js_config['deploy'].nil? ? true : js_config['deploy']
          @source = js_config['source'].nil? ? true : js_config['source']
          @uglify = js_config['uglify'].nil? ? true : js_config['uglify']
          # rubocop:enable Style/RedundantCondition

          @resource_name = 'JekyllWebmentionIO.js'
          @resource_url = File.join('', base_url, @destination, @resource_name)
        end

        def disabled?; @disabled; end

        def source?; @source; end

        def deploy?; @deploy; end

        def uglify?; @uglify; end
      end

      private

      def get_timeframe_from_date(time)
        date = time.to_date

        timeframe = nil

        TIMEFRAMES.each do |key, value|
          if date.to_date > get_date_from_string(value)
            timeframe = key
            break
          end
        end

        timeframe ||= 'older'
      end

      def get_date_from_string(text)
        today = Date.today
        pattern = /every\s(?:(\d+)\s)?(day|week|month|year)s?/
        matches = text.match(pattern)

        unless matches
          text = if text == 'daily'
                   'every 1 day'
                 else
                   "every 1 #{text.sub('ly', '')}"
                 end
          matches = text.match(pattern)
        end

        n = matches[1] ? matches[1].to_i : 1
        unit = matches[2]

        # weeks aren't natively supported in Ruby
        if unit == 'week'
          n *= 7
          unit = 'day'
        end

        # dynamic method call
        today.send "prev_#{unit}", n
      end
    end
  end
end
