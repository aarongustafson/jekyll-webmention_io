#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  this liquid plugin insert a webmentions into your Octopress or Jekill blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmention_reposts URL %}
#   
module Jekyll
  class WebmentionRepostsTag < WebmentionTag

    def initialize(tagName, text, tokens)
      super      
      set_template('reposts')
    end

    def set_data(data)
      webmentions = extract_type 'replies', data
      @data = { 'webmentions' => webmentions }
    end

  end
end

Liquid::Template.register_tag('webmention_reposts', Jekyll::WebmentionRepostsTag)