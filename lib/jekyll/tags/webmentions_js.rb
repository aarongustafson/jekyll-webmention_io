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
        site = context.registers[:site]

        # JS can be turned off too
        if site.config['webmentions']['js'] == false
          return
        end

        # JS file
        js_folder = 'js'
        if site.config['webmentions']['js'] and site.config['webmentions']['js']['destination']
          js_folder = site.config['webmentions']['js']['destination']
        end
        js_file_path = "#{site.config['baseurl']}/#{js_folder}/JekyllWebmentionIO.js"
        js << "<script src=\"#{js_file_path}\" async></script>"
        
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