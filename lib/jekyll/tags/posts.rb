#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  this liquid plugin insert a webmentions into your Octopress or Jekill blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmention_posts post.url %}
#   
module Jekyll
  module WebmentionIO
    class WebmentionRepostsTag < Jekyll::WebmentionIO::WebmentionTag

      def initialize(tagName, text, tokens)
        super      
        @text = text
        set_template 'posts'
      end

      def set_data(data)
        webmentions = extract_type 'posts', data
        @data = { 'webmentions' => webmentions.values }
      end

    end
  end
end

Liquid::Template.register_tag('webmention_posts', Jekyll::WebmentionIO::WebmentionRepostsTag)