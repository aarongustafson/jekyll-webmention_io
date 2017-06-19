#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  this liquid plugin insert a webmentions into your Octopress or Jekill blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmention_count URL %}
#   
module Jekyll
  class WebmentionCountTag < WebmentionTag

    def initialize(tagName, text, tokens)
      super
      
      set_template('count')

      # Get the URL
      args = @text.split(/\s+/).map(&:strip)
      url = args.first

      # Set the data
      if @cached_webmentions.has_key? url
        count = 0
        @cached_webmentions[url].each do |date, webmentions|
          size = size + webmentions.length
        end
        set_data({
          'count' => count
        })
      end

    end

  end
end

Liquid::Template.register_tag('webmention_count', Jekyll::WebmentionCountTag)