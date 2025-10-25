# frozen_string_literal: true

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  This generator gathers webmentions of your pages
#

require 'uglifier'
require 'fileutils'
require 'active_support'

module Jekyll
  module WebmentionIO
    class JavaScriptFile < StaticFile
      def destination_rel_dir
        WebmentionIO.js_handler.destination
      end
    end

    class CompileJS < Generator
      safe true
      priority :low

      def generate(site)
        @site = site

        if WebmentionIO.config.js.disabled?
          WebmentionIO.log 'info', 'Skipping JavaScript inclusion.'
          return
        end

        if @site.config['serving']
          Jekyll::WebmentionIO.log 'msg', 'A WebmentionIO.js source file will not be generated during `jekyll serve`.'
        end

        @file_name = WebmentionIO.config.js.resource_name

        @source_file_base_dir = if WebmentionIO.config.js.source? && !@site.config['serving']
                                  @site.in_source_dir
                                else
                                  Dir.mktmpdir
                                end

        @destination = WebmentionIO.config.js.destination
        @source_file_destination = File.join(@source_file_base_dir, @destination)

        @javascript = +'' # unfrozen String

        concatenate_asset_files
        add_webmention_types

        uglify if WebmentionIO.config.js.uglify?
        create_js_file
        deploy_js_file if WebmentionIO.config.js.deploy?
      end

      private

      def add_webmention_types
        js_types = []
        WebmentionIO.types.each do |type|
          js_types.push "'#{type}': '#{ActiveSupport::Inflector.singularize(type)}'"
        end
        types_js = <<-TYPES_JS
          ;(function(window,JekyllWebmentionIO){
            if ( ! ( \'JekyllWebmentionIO\' in window ) ){ window.JekyllWebmentionIO = {}; }
            JekyllWebmentionIO.types = { TYPES };
          }(this, this.JekyllWebmentionIO));
        TYPES_JS
        @javascript << types_js.sub('TYPES', js_types.join(','))
      end

      def concatenate_asset_files
        assets_dir = File.expand_path('../assets/', __dir__)
        Dir["#{assets_dir}/*.js"].each do |file|
          file_handler = File.open(file, 'rb')
          @javascript << File.read(file_handler)
        end
      end

      def uglify
        @javascript = Uglifier.new(harmony: true).compile(@javascript)
      end

      def create_js_file
        FileUtils.mkdir_p(@source_file_destination) unless File.exist?(@source_file_destination)
        File.open(File.join(@source_file_destination, @file_name), 'wb') { |f| f.write(@javascript) }
      end

      def deploy_js_file
        js_file = WebmentionIO::JavaScriptFile.new(@site, @source_file_base_dir, @destination, @file_name)
        @site.static_files << js_file
      end
    end
  end
end
