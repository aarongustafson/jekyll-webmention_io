#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT

module Jekyll
  module WebmentionIo

    class WebmentionHeadTags < Liquid::Tag

      def initialize(tag_name, text, tokens)
        super
        # @text = text
      end

      def render(context)
        out = ""

        config = context.registers[:site].config
        domain = config['jekyll-webmention-io']['domain'] || false
        
        if domain
          out += %Q(<link rel="webmention" href="https://webmention.io/#{domain}/webmention" />\n)
          out += %Q(<link rel="pingback" href="https://webmention.io/#{domain}/xmlrpc" />\n)
        end

        return out
      end
    end

  end
end

Liquid::Template.register_tag('webmention_head_tags', Jekyll::WebmentionIo::WebmentionHeadTags)
