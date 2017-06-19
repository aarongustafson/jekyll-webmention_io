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
      set_api_endpoint('count')
      set_template('count')
    end

    def set_data( response )
      count = response['count'] || 0
      set_data({
        'count': count
      })
    end

  end
end

Liquid::Template.register_tag('webmention_count', Jekyll::WebmentionCountTag)