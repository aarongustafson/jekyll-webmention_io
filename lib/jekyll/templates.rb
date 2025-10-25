# frozen_string_literal: true

module Jekyll
  module WebmentionIO
    class Templates
      attr_reader :supported_templates

      def initialize(site)
        @site = site

        @supported_templates = (WebmentionIO.types + %w(count webmentions)).freeze

        @template_file_cache = {}
        @template_content_cache = {}
      end

      def template_contents(template)
        template_file = template_file(template)
        @template_content_cache[template_file] ||= begin
          WebmentionIO.log 'info', "Template file: #{template_file}"
          File.read(template_file)
        end
      end

      def html_templates
        setting = WebmentionIO.config.html_proofer_ignore
        proofer = if [Config::HtmlProofer::ALL, Config::HtmlProofer::TEMPLATES].include?(setting)
                    ' data-proofer-ignore'
                  else
                    ''
                  end
        @html_templates ||= begin
          templates = +'' # unfrozen String
          supported_templates.each do |template|
            templates << "<template style=\"display:none\" id=\"webmention-#{template}\"#{proofer}>"
            templates << template_contents(template)
            templates << '</template>'
          end
          templates
        end
      end

      private

      def template_file(template)
        @template_file_cache[template] ||= begin
          configured_template = WebmentionIO.config.templates[template]

          if configured_template
            WebmentionIO.log 'info', "Using custom #{template} template from site source"
            @site.in_source_dir configured_template
          else
            File.expand_path("templates/#{template}.html", __dir__)
          end
        end
      end
    end
  end
end
