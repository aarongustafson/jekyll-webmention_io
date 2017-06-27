#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  JS stuff
#

module Jekyll
  module WebmentionIO
    using StringInflection
    class WebmentionJSTag < Liquid::Tag
      def render(context)
        js = '<script>'
        js << 'if ( ! ( \'JekyllWebmentionIO\' in window ) ){ window.JekyllWebmentionIO = {}; }'
        js << 'window.JekyllWebmentionIO.types = { '
        js_types = []
        Jekyll::WebmentionIO::types.each do |type|
          js_types.push "'#{type}': '#{type.to_singular}'"
        end
        js << js_types.join(',')
        js << '};</script>'
        
        templates = ''
        template_files = Jekyll::WebmentionIO::types + ['count', 'webmentions']
        template_files.each do |template|
          if Jekyll::WebmentionIO::config.has_key? 'templates' and Jekyll::WebmentionIO::config['templates'].has_key? template
            # Jekyll::WebmentionIO::log 'info', "Using custom #{template} template"
            template_file = Jekyll::WebmentionIO::config['templates'][template]
          else
            # Jekyll::WebmentionIO::log 'info', "Using default #{template} template"
            template_file = File.join(File.dirname(File.expand_path(__FILE__)), "../templates/#{template}.html")
          end
          # Jekyll::WebmentionIO::log 'info', "Template file: #{template_file}"
          handler = File.open(template_file, 'rb')
          template_contents = handler.read

          templates << "<template id=\"webmention-#{template}\">#{template_contents}</template>"
        end
        
        "#{js}\n#{templates}"
      end
    end
  end
end

Liquid::Template.register_tag('webmentions_js', Jekyll::WebmentionIO::WebmentionJSTag)