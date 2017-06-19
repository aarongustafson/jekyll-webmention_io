#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  this liquid plugin insert a webmentions into your Octopress or Jekill blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmention_replies URL %}
#   
module Jekyll
  class WebmentionRepliesTag < WebmentionTag

    def initialize(tagName, text, tokens)
      super
      
      set_template('replies')

      # Get the URL
      args = @text.split(/\s+/).map(&:strip)
      url = args.first

      # Set the data
      if @cached_webmentions.has_key? url
        set_data({
          'webmentions' => get_webmentions_by_type( url, 'replies' )
        })
      end

    end

  end
end

Liquid::Template.register_tag('webmention_replies', Jekyll::WebmentionRepliesTag)