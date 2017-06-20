#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  this liquid plugin insert a webmentions into your Octopress or Jekill blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmentions URL %}
#   
module Jekyll
  class WebmentionsTag < WebmentionTag
  
    def initialize(tagName, text, tokens)
      super

      # Set the template
      set_template('all')

      # Get the URL
      args = @text.split(/\s+/).map(&:strip)
      url = args.first

      # Update the data
      if @cached_webmentions.has_key? url
        set_data(@cached_webmentions[url])
      end

    end

  end

end

Liquid::Template.register_tag('webmentions', Jekyll::WebmentionsTag)