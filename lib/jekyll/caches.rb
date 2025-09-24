# frozen_string_literal: true

require 'forwardable'

module Jekyll
  module WebmentionIO
    class Caches
      def initialize(site)
        @cache_folder = site.in_source_dir(site.config["cache_folder"] || ".jekyll-cache")

        Dir.mkdir(@cache_folder) unless File.exist?(@cache_folder)
      end

      def incoming_webmentions
        @@incoming_webmentions ||= Cache.new(cache_file_path("incoming"))
      end

      def outgoing_webmentions
        @@outgoing_webmentions ||= Cache.new(cache_file_path("outgoing"))
      end

      def bad_uris
        @@bad_uris ||= Cache.new(cache_file_path("bad_uris"))
      end

      def site_lookups
        @@site_lookups ||= Cache.new(cache_file_path("lookups"))
      end

      private

      def cache_file_path(name)
        Jekyll.sanitized_path(@cache_folder, "webmention_io_#{name}.yaml")
      end

      class Cache
        extend Forwardable

        def_delegator :@data, :each
        def_delegator :@data, :key?
        def_delegator :@data, :delete
        def_delegator :@data, :dig
        def_delegator :@data, :[]
        def_delegator :@data, :[]=

        def initialize(path)
          # NOTE: This is a deviation from the old code! Previously if the configured
          # cache folder had the word "webmention" in it, the "webmention_io" prefix
          # would be removed, but the extra complexity wasn't worth replicating.
          @path = path

          begin
            @data = SafeYAML.load_file(path)
          rescue
            @data = {}
          end
        end

        def write
          File.open(@path, "wb") { |f| f.puts YAML.dump(@data) }
        end

        def empty?
          @data.empty?
        end

        def clear
          @data = {}
          File.delete(@path)
        end
      end

      private_constant :Cache
    end
  end
end
