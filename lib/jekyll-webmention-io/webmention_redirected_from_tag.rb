#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT

module Jekyll
  module WebmentionIo

    class WebmentionRedirectedFromTag < Liquid::Tag

      def initialize(tag_name, text, tokens)
        super
        @redirect_keys = text.strip.split(%r{,\s*|\s+})
      end

      def render(context)
        urls = []

        page = context.registers[:page]

        # Grab all of the urls
        @redirect_keys.each do |key|
          if page.has_key?(key)
            if page[key].kind_of?(Array)
              page[key].each do |u|
                urls << u
              end
            else
              urls << page[key]
            end
          end
        end

        # TODO: Ensure they're fully qualified http://domain/foo urls?

        return %Q(<meta property="webmention:redirected_from" content="#{urls.join(',')}">)
      end
    end

  end
end

Liquid::Template.register_tag('webmention_redirected_from', Jekyll::WebmentionIo::WebmentionRedirectedFromTag)
