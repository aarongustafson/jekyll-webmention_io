#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  this liquid plugin insert a webmentions into your Octopress or Jekill blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmention_likes URL %}
#   
module Jekyll
  class WebmentionLikesTag < WebmentionTag

    def initialize(tagName, text, tokens)
      super
      
      set_template('likes')

      # Get the URL
      args = @text.split(/\s+/).map(&:strip)
      url = args.first

      # Set the data
      if @cached_webmentions.has_key? url
        set_data({
          'webmentions' => get_webmentions_by_type( url, 'likes' )
        })
      end

    end

  end
end

Liquid::Template.register_tag('webmention_likes', Jekyll::WebmentionLikesTag)