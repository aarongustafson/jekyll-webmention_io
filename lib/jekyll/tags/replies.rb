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
  class WebmentionRepliesTag < WebmentionTag
    
    def initialize(tagName, text, tokens)
      super
      set_api_endpoint('count')
    end

    def html_output_for(response)
      count = response['count'] || '0'
      "<span class=\"webmention-count\">#{count}</span>"
    end
    
  end
end

Liquid::Template.register_tag('webmention_replies', Jekyll::WebmentionCountTag)