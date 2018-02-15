# frozen_string_literal: false

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  Base webmention tag
#

require "htmlbeautifier"

module Jekyll
  module WebmentionIO
    using StringInflection
    class WebmentionTag < Liquid::Tag

      def initialize(tag_name, text, tokens)
        super
        cache_file = Jekyll::WebmentionIO.get_cache_file_path "incoming"
        @cached_webmentions = if File.exist? cache_file
                                open(cache_file) { |f| YAML.load(f) }
                              else
                                {}
                              end
      end

      def lookup(context, name)
        lookup = context
        name&.split(".")&.each do |value|
          lookup = lookup[value]
        end
        lookup
      end

      def set_template(template)
        supported_templates = Jekyll::WebmentionIO.types + %w(count webmentions)
        Jekyll::WebmentionIO.log "error", "#{template} is not supported" unless supported_templates.include? template
        @template = Jekyll::WebmentionIO.get_template_contents(template)
        # Jekyll::WebmentionIO.log "info", "template: #{@template}"
      end

      def set_data(data, types)
        @data = { "webmentions" => data, "types" => types }
      end

      def extract_type(type, webmentions)
        # Jekyll::WebmentionIO.log "info", "Looking for #{type}"
        keep = {}
        if !Jekyll::WebmentionIO.types.include? type
          Jekyll::WebmentionIO.log "warn", "#{type} are not extractable"
        else
          type = type.to_singular
          # Jekyll::WebmentionIO.log 'info', "Searching #{webmentions.length} webmentions for type==#{type}"
          if webmentions.is_a? Hash
            webmentions = webmentions.values
          end
          webmentions.each do |webmention|
            keep[webmention["id"]] = webmention if webmention["type"] == type
          end
        end
        keep
      end

      def sort_webmentions(webmentions)
        return webmentions.sort_by { |webmention| webmention["pubdate"].to_i }
      end

      def render(context)
        # Get the URI
        args = @text.split(/\s+/).map(&:strip)
        uri = args.shift
        uri = lookup(context, uri)

        # capture the types in case JS needs them
        types = []

        if @cached_webmentions.key? uri
          all_webmentions = @cached_webmentions[uri].clone
          # Jekyll::WebmentionIO.log 'info', "#{all_webmentions.length} total webmentions for #{uri}"

          if args.length.positive?
            # Jekyll::WebmentionIO.log 'info', "Requesting only #{args.inspect}"
            webmentions = {}
            args.each do |type|
              types.push type
              extracted = extract_type(type, all_webmentions)
              # Jekyll::WebmentionIO.log 'info', "Merging in #{extracted.length} #{type}"
              webmentions = webmentions.merge(extracted)
            end
          else
            # Jekyll::WebmentionIO.log 'info', 'Grabbing all webmentions'
            webmentions = all_webmentions
          end

          if webmentions.is_a? Hash
            webmentions = webmentions.values
          end

          webmentions = sort_webmentions(webmentions)
          set_data(webmentions, types)
        end

        # args = nil

        if @template && @data
          # Jekyll::WebmentionIO.log 'info', "Preparing to render\n\n#{@data.inspect}\n\ninto\n\n#{@template}"
          template = Liquid::Template.parse(@template, :error_mode => :strict)
          html = template.render(@data, { :strict_variables => false, :strict_filters => true })
          template.errors.each do |error|
            Jekyll::WebmentionIO.log "error", error
          end
          # Clean up the output
          HtmlBeautifier.beautify html.each_line.reject { |x| x.strip == "" }.join
        else
          unless @template
            Jekyll::WebmentionIO.log "warn", "#{self.class} No template provided"
          end
          unless @data
            Jekyll::WebmentionIO.log "warn", "#{self.class} No data provided"
          end
          ""
        end
      end
    end
  end
end
