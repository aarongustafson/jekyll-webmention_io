#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  this liquid plugin insert a webmentions into your Octopress or Jekill blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmention_links post.url %}
#   
module Jekyll
  class WebmentionLinksTag < WebmentionTag

    def initialize(tagName, text, tokens)
      super
      @text = text
      set_template 'links'
    end

    def set_data(data)
      webmentions = extract_type 'links', data
      @data = { 'webmentions' => webmentions.values }
    end

  end
end

Liquid::Template.register_tag('webmention_links', Jekyll::WebmentionLinksTag)