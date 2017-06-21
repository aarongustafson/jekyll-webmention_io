#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  this liquid plugin insert a webmentions into your Octopress or Jekill blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmention_count post.url [ likes | links | posts | replies | reposts ]*   %}
#   
module Jekyll
  class WebmentionCountTag < WebmentionTag

    def initialize(tagName, text, tokens)
      super
      @text = text
      set_template 'count'
    end

    def set_data(data)
      @data = { 'count' => data.length }
    end

  end
end

Liquid::Template.register_tag('webmention_count', Jekyll::WebmentionCountTag)