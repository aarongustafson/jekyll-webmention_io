#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT

module Jekyll
  module WebmentionIo
    class WebmentionCountTag < Webmentions
      
      def initialize(tagName, text, tokens)
        super
        @api_endpoint = 'http://webmention.io/api/count'
      end

      def html_output_for(response)
        count = response['count'] || '0'
        "<span class=\"webmention-count\">#{count}</span>"
      end
      
    end
  end
end

Liquid::Template.register_tag('webmention_count', Jekyll::WebmentionIo::WebmentionCountTag)
