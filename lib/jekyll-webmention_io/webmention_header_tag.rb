#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT

module Jekyll
  module WebmentionIo

    class WebmentionHeaderTag < Liquid::Tag
      @@warned = {}

      def initialize(tag_name, text, tokens)
        super
        # @text = text
      end

      def render(context)
        site = context.registers[:site]

        if site.config['jekyll-webmention-io']
          @config = site.config['jekyll-webmention-io']
        else
          if !@@warned.has_key?('config')
            Jekyll.logger.warn "jekyll-webmention-io:", "_config.yml key not defined: jekyll-webmention-io"
            @@warned['config'] = true
          end

          return ""
        end

        if @config.has_key?('domain')
          @domain = @config['domain']
        else
          if !@@warned.has_key?('domain')
            Jekyll.logger.warn "jekyll-webmention-io:", "_config.yml key not defined: jekyll-webmention-io.domain"
            @@warned['domain'] = true
          end

          return ""
        end

        out = ""

        if @domain
          out += "<link rel=\"webmention\" href=\"https://webmention.io/#{@domain}/webmention\" />\n"
          out += "<link rel=\"pingback\" href=\"https://webmention.io/#{@domain}/xmlrpc\" />\n"
        end

        return out
      end
    end

  end
end

Liquid::Template.register_tag('webmention_head_tags', Jekyll::WebmentionIo::WebmentionHeaderTag)
