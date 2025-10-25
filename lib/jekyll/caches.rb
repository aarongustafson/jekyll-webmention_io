# frozen_string_literal: true

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
    class Caches
      def initialize(config)
        @config = config

        FileUtils.makedirs(@config.cache_folder)
      end

      def incoming_webmentions
        @@incoming_webmentions ||= Cache.new(cache_file_path('incoming'))
      end

      def outgoing_webmentions
        @@outgoing_webmentions ||= Cache.new(cache_file_path('outgoing'))
      end

      def bad_uris
        @@bad_uris ||= Cache.new(cache_file_path('bad_uris'))
      end

      def site_lookups
        @@site_lookups ||= Cache.new(cache_file_path('lookups'))
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
        def_delegator :@data, :dig
        def_delegator :@data, :[]
        def_delegator :@data, :[]=
        def_delegator :@data, :empty?

        def initialize(path)
          # NOTE: This is a deviation from the old code! Previously if the configured
          # cache folder had the word 'webmention' in it, the 'webmention_io' prefix
          # would be removed, but the extra complexity wasn't worth replicating.
          @path = path

          begin
            @data = SafeYAML.load_file(path)
          rescue StandardError
            @data = {}
          end
        end

        def write
          File.open(@path, 'wb') { |f| f.puts YAML.dump(@data) }
        end

        def clear
          @data = {}
          File.delete(@path) if File.exist?(@path)
        end
      end

      private_constant :Cache
    end
  end
end
