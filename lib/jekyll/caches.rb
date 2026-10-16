# frozen_string_literal: true

require 'date'
require 'forwardable'
require 'fileutils'

module Jekyll
  module WebmentionIO
    # The Caches class is a utility service that provides access to the cache files used
    # by this plugin.
    #
    # It is initialized with a config object and creates a folder in the configured cache folder
    # to store the cache files.
    #
    # The class is a singleton and the instance is accessed via the WebmentionIO.caches method.
    class IncomingWebmentions
      attr_reader :key, :webmentions

      def initialize(key, val)
        @key = key

        if val.is_a?(Hash) && val.key?('webmentions')
          @webmentions = val['webmentions'] || {}
          @canonical_urls = val['canonical_urls'] || []
        else
          # Cache files written before the URLs were kept alongside the mentions hold
          # the mentions on their own.
          @webmentions = val || {}
          @canonical_urls = []
        end
      end

      # Every URL the service has reported for this post's mentions, oldest first.
      # A page's mentions can be merged into another page, which changes the URL they
      # come back under, so these accumulate rather than being replaced -- and the
      # ones already held outlive the mentions behind them, if those ever go.
      def canonical_urls
        reported = mention_list.filter_map { |webmention| webmention.dig('raw', 'target') }

        @canonical_urls |= reported
      end

      def to_val
        { 'webmentions' => webmentions, 'canonical_urls' => canonical_urls }
      end

      # The highest wm-id held for this post: everything at or below it has been seen,
      # so it is the boundary to ask from. nil when nothing is cached, which means the
      # whole history is still to come.
      #
      # Taken from the raw API entries rather than the cache keys, which are rewritten
      # for some sources (see WebmentionItem#determine_id).
      def highest_id
        mention_list.filter_map { |webmention| webmention.dig('raw', 'id')&.to_i }.max
      end

      # The newest date any mention held for this post was verified, which is the best
      # answer there is for when this post was last looked at, for when the lookup cache
      # has nothing to say.
      def last_heard_at
        mention_list.filter_map { |webmention| parse_verified_date(webmention) }.max
      end

      private

      # Older cache files held the mentions as a plain list rather than keyed by id.
      # A mention's verified date, or nil when it carries none we can read.
      def parse_verified_date(webmention)
        Date.parse(webmention.dig('raw', 'verified_date').to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def mention_list
        @webmentions.is_a?(Hash) ? @webmentions.values : @webmentions
      end
    end

    class OutgoingWebmentions
      attr_reader :webmentions

      def initialize(key, value)
        @key = key
        @webmentions = value || {}
      end

      def to_val
        @webmentions
      end
    end

    class BadUri
      attr_reader :key, :state, :attempts, :last_check_date

      def initialize(key, value)
        @key = key

        if value.is_a?(Hash)
          @state = value['state']
          @attempts = value['attempts']
          @last_check_date = parse_check_date(value['last_checked'])
        else
          # Older cache files stored the check date on its own, with no state: a
          # target that was found unsupported and tried once.
          @state = 'unsupported'
          @attempts = 1
          @last_check_date = parse_check_date(value)
        end
      end

      def to_val
        { 'state' => state, 'attempts' => attempts, 'last_checked' => last_check_date.to_s }
      end

      private

      # The policy does arithmetic on the check date, so it is kept as a Time.
      def parse_check_date(value)
        DateTime.parse(value.to_s).to_time
      rescue ArgumentError, TypeError
        nil
      end
    end

    class SiteLookup
      attr_reader :key, :last_check_date

      def initialize(key, value)
        @key = key
        @last_check_date = value
      end

      def to_val
        @last_check_date
      end
    end

    class Caches
      def initialize(config)
        @config = config

        FileUtils.makedirs(@config.cache_folder)
      end

      def incoming_webmentions
        @@incoming_webmentions ||= Cache.new(cache_file_path('incoming'), IncomingWebmentions)
      end

      def outgoing_webmentions
        @@outgoing_webmentions ||= Cache.new(cache_file_path('outgoing'), OutgoingWebmentions)
      end

      def bad_uris
        @@bad_uris ||= Cache.new(cache_file_path('bad_uris'), BadUri)
      end

      def site_lookups
        @@site_lookups ||= Cache.new(cache_file_path('lookups'), SiteLookup)
      end

      # Resets all singleton cache instances by clearing the class variables.
      # This is useful for testing to ensure clean state between tests.
      def self.reset
        @@incoming_webmentions = nil
        @@outgoing_webmentions = nil
        @@bad_uris = nil
        @@site_lookups = nil
      end

      private

      def cache_file_path(name)
        Jekyll.sanitized_path(@config.cache_folder, "webmention_io_#{name}.yml")
      end

      # A class that represents a single cache file. The initalizer takes a full path
      # where the cache data will be stored and retrieved.
      #
      # Upon initialization the current contents of the cache are loaded. Writes are not
      # saved until the `write` method is called.
      class Cache
        extend Forwardable

        attr_reader :path

        def_delegator :@data, :each
        def_delegator :@data, :key?
        def_delegator :@data, :delete
        def_delegator :@data, :[]
        def_delegator :@data, :empty?
        def_delegator :@data, :map
        def_delegator :@data, :to_h

        def initialize(path, klass)
          # NOTE: This is a deviation from the old code! Previously if the configured
          # cache folder had the word 'webmention' in it, the 'webmention_io' prefix
          # would be removed, but the extra complexity wasn't worth replicating.
          @path = path
          @klass = klass
          @data = {}

          begin
            SafeYAML.load_file(path).each { |key, val| @data[key] = klass.new(key, val) }
          rescue StandardError
            @data = {}
          end
        end

        # Store a value, wrapped in whatever this cache holds, so a caller never has
        # to build the object itself.
        def store(key, value)
          @data[key] = @klass.new(key, value)
        end

        # The entry for a key, created empty when the cache has nothing for it.
        def entry(key)
          @data[key] || store(key, nil)
        end

        def write
          File.open(@path, 'wb') { |f| f.puts YAML.dump(@data.transform_values(&:to_val)) }
        end

        def clear
          @data = {}
          FileUtils.rm_f(@path)
        end
      end

      private_constant :Cache
    end
  end
end
