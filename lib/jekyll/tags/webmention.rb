# frozen_string_literal: true

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  Base webmention tag
#

require 'htmlbeautifier'

module Jekyll
  module WebmentionIO
    class WebmentionTag < Liquid::Tag
      def lookup(context, name)
        lookup = context
        name&.split('.')&.each do |value|
          lookup = lookup[value]
        end
        lookup
      end

      def template=(template)
        unless WebmentionIO.templates.supported_templates.include? template
          WebmentionIO.log 'error', "#{template.capitalize} is not supported"
        end
        @template_name = template
        @template = WebmentionIO.templates.template_contents(template)
        WebmentionIO.log 'info', "#{template.capitalize} template:\n\n#{@template}\n\n"
      end

      def set_data(data, types, html_proofer_ignore)
        @data = { 'webmentions' => data, 'types' => types, 'html_proofer_ignore' => html_proofer_ignore }
      end

      def extract_type(type, webmentions)
        WebmentionIO.log 'info', "Looking for #{type}"
        keep = {}
        if WebmentionIO.types.include? type
          type = ActiveSupport::Inflector.singularize(type)
          WebmentionIO.log 'info', "Searching #{webmentions.length} webmentions for type==#{type}"
          if webmentions.is_a? Hash
            webmentions = webmentions.values
          end
          webmentions.each do |webmention|
            keep[webmention['id']] = webmention if webmention['type'] == type
          end
        else
          WebmentionIO.log 'warn', "#{type} are not extractable"
        end
        keep
      end

      def render(context)
        # Initialize an empty set of webmentions (we'll populate later if
        # there actually are any).
        webmentions = []

        # Capture the types in case JS needs them
        types = []

        # Get the URI
        args = @text.split(/\s+/).map(&:strip)
        uri = args.shift
        uri = lookup(context, uri)

        cached_webmentions = WebmentionIO.caches.incoming_webmentions

        if cached_webmentions.key? uri
          all_webmentions = cached_webmentions[uri].clone
          WebmentionIO.log 'info', "#{all_webmentions.length} total webmentions for #{uri}"

          if args.length.positive?
            WebmentionIO.log 'info', "Requesting only #{args.inspect}"
            webmentions = {}
            args.each do |type|
              types.push type
              extracted = extract_type(type, all_webmentions)
              WebmentionIO.log 'info', "Merging in #{extracted.length} #{type}"
              webmentions = webmentions.merge(extracted)
            end
          else
            WebmentionIO.log 'info', 'Grabbing all webmentions'
            webmentions = all_webmentions
          end

          if webmentions.is_a? Hash
            webmentions = webmentions.values
          end

          webmentions = sort_webmentions(webmentions)
        end

        set_data(webmentions, types, WebmentionIO.config.html_proofer_ignore)
        render_into_template(context.registers)
      end

      private

      def render_into_template(context_registry)
        if @template && @data
          WebmentionIO.log 'info', "Preparing to render webmention info into the #{@template_name} template."
          template = Liquid::Template.parse(@template, error_mode: :strict)
          html = template.render!(@data, registers: context_registry, strict_variables: false, strict_filters: true)
          template.errors.each do |error|
            WebmentionIO.log 'error', error
          end
          # Clean up the output
          HtmlBeautifier.beautify html.each_line.reject { |x| x.strip == '' }.join
        else
          unless @template
            WebmentionIO.log 'warn', "#{self.class} No template provided"
          end
          unless @data
            WebmentionIO.log 'warn', "#{self.class} No data provided"
          end
          ''
        end
      end

      def sort_webmentions(webmentions)
        webmentions.sort_by { |webmention| webmention['pubdate'].to_i }
      end
    end
  end
end
