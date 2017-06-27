#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  Stuff for the `head`
#

module Jekyll
  module WebmentionIO
    class WebmentionHeadTag < Liquid::Tag
      def render(context)
        head = ''
        head << '<link rel="dns-prefetch" href="//webmention.io">'
        head << '<link rel="preconnect" href="//webmention.io">'
        head << '<link rel="preconnect" href="ws://webmention.io:8080">'
        
        page = context['page']
        site = context.registers[:site]
        if page['redirect_from']
          if page['redirect_from'].is_a? String
            redirect = site.config['url'] + page['redirect_from']
          elsif page['redirect_from'].is_a? Array
            redirect = site.config['url'] + page['redirect_from'].join(",#{site.config['url']}")
          end
          head << "<meta property=\"webmention:redirected_from\" value=\"#{redirect}\">"
        end

        head
      end
    end
  end
end

Liquid::Template.register_tag('webmentions_head', Jekyll::WebmentionIO::WebmentionHeadTag)