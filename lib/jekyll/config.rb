# frozen_string_literal: true

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

      attr_accessor :html_proofer_ignore, :max_attempts,
                    :templates, :bad_uri_policy, :throttle_lookups, :cache_folder,
                    :legacy_domains, :pause_lookups, :site_url, :syndication, :js,
                    :username

      def initialize(site = nil)
        @site = site

        if !site.nil?
          parse(@site.config['webmentions'], @site.config['baseurl'].to_s, @site.config['url'].to_s)
        else
          parse
        end
      end

      def parse(config = nil, site_url = '', base_url = '')
        config ||= {}

        @site_url = site_url
        @username = config['username']

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

        @js = JsConfig.new(base_url, config['js'] || {})

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
          WebmentionIO.log "info", "Including site pages."
          documents.concat @site.pages.clone
        end

        if @collections.empty?
          WebmentionIO.log "info", "Adding collections."

          @site.collections.each do |name, collection|
            # skip _posts
            next if name == "posts"

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

          # We always want to collection webmentions from webmention.io, so we
          # explicitly flag it. This way if there's a service outage, we don't
          # end up banning the URL.
          @bad_uri_policy['whitelist'].insert(-1, '^https?://webmention.io/')

          @whitelist = @bad_uri_policy['whitelist'].map { |expr| Regexp.new(expr) }
          @blacklist = @bad_uri_policy['blacklist'].map { |expr| Regexp.new(expr) }
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
      end

      class SyndicationRule
        attr_reader :endpoint, :response_mapping

        def initialize(entry)
          @endpoint = entry[endpoint]
          @response_mapping = {}

          if entry.key?('response_mapping')
            entry['response_mapping'].each do |key, pattern|
              begin
                @response_mapping[key] = JsonPath.new(pattern)
              rescue StandardError => e
                WebmentionIO.log "error", "Ignoring invalid JsonPath expression #{pattern}: #{e}"
              end
            end
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
          @deploy = js_config['deploy'] || true
          @source = js_config['source'] || true
          @uglify = js_config['uglify'] || true

          @resource_name = "JekyllWebmentionIO.js"
          @resource_url = File.join("", base_url, @destination, @resource_name)
        end

        def disabled?; @disabled; end
        def source?; @source; end
        def deploy?; @deploy; end
        def uglify?; @uglify; end
      end

      private

      TIMEFRAMES = {
        'last_week' => 'weekly',
        'last_month' => 'monthly',
        'last_year' => 'yearly',
      }.freeze

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
