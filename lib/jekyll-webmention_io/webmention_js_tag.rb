#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT

module Jekyll
  module WebmentionIo

    class WebmentionJsTag < Liquid::Tag

      def initialize(tag_name, text, tokens)
        super
        # @text = text
      end

      def render(context)
        config = context.registers[:site].config
        
        jsdir = config['jekyll-webmention-io']['js'] || "/assets/js/"
        js = File.join(jsdir, "webmention_io.js")

        return %Q(<script type="text/javascript" src="#{js}"></script>)
      end
    end

  end
end

Liquid::Template.register_tag('webmention_js_tag', Jekyll::WebmentionIo::WebmentionJsTag)
