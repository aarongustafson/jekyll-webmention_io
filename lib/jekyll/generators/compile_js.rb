# frozen_string_literal: true

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  This generator gathers webmentions of your pages
#

require "uglifier"

module Jekyll
  module WebmentionIO
    class JavaScriptFile < StaticFile
      def destination_rel_dir
        WebmentionIO.js_handler.destination
      end
    end

    using StringInflection
    class CompileJS < Generator
      safe true
      priority :low

      def generate(site)
        handler = WebmentionIO.js_handler
        @site = site
        @file_name = handler.resource_name

        if handler.disabled?
          WebmentionIO.log "info", "Skipping JavaScript inclusion."
          return
        end

        @source_file_destination = if handler.source?
                                     @site.in_source_dir(handler.destination)
                                   else
                                     Dir.mktmpdir
                                   end

        @javascript = +"" # unfrozen String

        concatenate_asset_files
        add_webmention_types

        uglify if handler.uglify?
        create_js_file
        deploy_js_file if handler.deploy?
      end

      private

      def add_webmention_types
        js_types = []
        WebmentionIO.types.each do |type|
          js_types.push "'#{type}': '#{type.to_singular}'"
        end
        types_js = <<-EOF
          ;(function(window,JekyllWebmentionIO){
            if ( ! ( \'JekyllWebmentionIO\' in window ) ){ window.JekyllWebmentionIO = {}; }
            JekyllWebmentionIO.types = { TYPES };
          }(this, this.JekyllWebmentionIO));
        EOF
        @javascript << types_js.sub("TYPES", js_types.join(","))
      end

      def concatenate_asset_files
        assets_dir = File.expand_path("../assets/", __dir__)
        Dir["#{assets_dir}/*.js"].each do |file|
          file_handler = File.open(file, "rb")
          @javascript << File.read(file_handler)
        end
      end

      def uglify
        @javascript = Uglifier.new(:harmony => true).compile(@javascript)
      end

      def create_js_file
        Dir.mkdir(@source_file_destination) unless File.exist?(@source_file_destination)
        File.open(File.join(@source_file_destination, @file_name), "wb") { |f| f.write(@javascript) }
      end

      def deploy_js_file
        js_file = WebmentionIO::JavaScriptFile.new(@site, @source_file_destination, "", @file_name)
        @site.static_files << js_file
      end
    end
  end
end
