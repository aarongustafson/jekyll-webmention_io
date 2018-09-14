# frozen_string_literal: true

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
        cache_file = WebmentionIO.get_cache_file_path "incoming"
        @cached_webmentions = if File.exist? cache_file
                                WebmentionIO.load_yaml(cache_file)
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

      def template=(template)
        unless WebmentionIO.supported_templates.include? template
          WebmentionIO.log "error", "#{template.capitalize} is not supported"
        end
        @template_name = template
        @template = WebmentionIO.get_template_contents(template)
        WebmentionIO.log "info", "#{template.capitalize} template:\n\n#{@template}\n\n"
      end

      def set_data(data, types)
        @data = { "webmentions" => data, "types" => types }
      end

      def extract_type(type, webmentions)
        WebmentionIO.log "info", "Looking for #{type}"
        keep = {}
        if !WebmentionIO.types.include? type
          WebmentionIO.log "warn", "#{type} are not extractable"
        else
          type = type.to_singular
          WebmentionIO.log "info", "Searching #{webmentions.length} webmentions for type==#{type}"
          if webmentions.is_a? Hash
            webmentions = webmentions.values
          end
          webmentions.each do |webmention|
            keep[webmention["id"]] = webmention if webmention["type"] == type
          end
        end
        keep
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
          WebmentionIO.log "info", "#{all_webmentions.length} total webmentions for #{uri}"

          if args.length.positive?
            WebmentionIO.log "info", "Requesting only #{args.inspect}"
            webmentions = {}
            args.each do |type|
              types.push type
              extracted = extract_type(type, all_webmentions)
              WebmentionIO.log "info", "Merging in #{extracted.length} #{type}"
              webmentions = webmentions.merge(extracted)
            end
          else
            WebmentionIO.log "info", "Grabbing all webmentions"
            webmentions = all_webmentions
          end

          if webmentions.is_a? Hash
            webmentions = webmentions.values
          end

          webmentions = sort_webmentions(webmentions)
          set_data(webmentions, types)
        end

        render_into_template(context.registers)
      end

      private

      def render_into_template(context_registry)
        if @template && @data
          WebmentionIO.log "info", "Preparing to render webmention info into the #{@template_name} template."
          template = Liquid::Template.parse(@template, :error_mode => :strict)
          html = template.render!(@data, :registers => context_registry, :strict_variables => false, :strict_filters => true)
          template.errors.each do |error|
            WebmentionIO.log "error", error
          end
          # Clean up the output
          HtmlBeautifier.beautify html.each_line.reject { |x| x.strip == "" }.join
        else
          unless @template
            WebmentionIO.log "warn", "#{self.class} No template provided"
          end
          unless @data
            WebmentionIO.log "warn", "#{self.class} No data provided"
          end
          ""
        end
      end

      def sort_webmentions(webmentions)
        return webmentions.sort_by { |webmention| webmention["pubdate"].to_i }
      end
    end
  end
end
