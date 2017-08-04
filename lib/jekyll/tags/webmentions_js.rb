#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  JS stuff
#

module Jekyll
  module WebmentionIO
    class WebmentionJSTag < Liquid::Tag
      def render(context)
        site = context.registers[:site]

        # JS can be turned off too
        if site.config.dig( 'webmentions', 'js' ) == false
          Jekyll::WebmentionIO::log 'info', 'JavaScript output is disabled, so the {% webmentions_js %} tag is being skipped'
          return ''
        end

        config = {
          'destination' => 'js',
          'uglify'      => true
        }
        site_config = site.config.dig( 'webmentions', 'js' ) || {}        
        config = config.merge(site_config)

        # JS file
        js = ''
        unless config['deploy'] == false
          js_file_path = "#{site.config['baseurl']}/#{config['destination']}/JekyllWebmentionIO.js"
          js << "<script src=\"#{js_file_path}\" async></script>"
        end
        
        templates = ''
        template_files = Jekyll::WebmentionIO::types + ['count', 'webmentions']
        template_files.each do |template|
          if Jekyll::WebmentionIO::config.dig( 'templates', template )
            # Jekyll::WebmentionIO::log 'info', "Using custom #{template} template"
            template_file = Jekyll::WebmentionIO::config['templates'][template]
          else
            # Jekyll::WebmentionIO::log 'info', "Using default #{template} template"
            template_file = File.join(File.dirname(File.expand_path(__FILE__)), "../templates/#{template}.html")
          end
          # Jekyll::WebmentionIO::log 'info', "Template file: #{template_file}"
          handler = File.open(template_file, 'rb')
          template_contents = handler.read

          templates << "<template style=\"display:none\" id=\"webmention-#{template}\">#{template_contents}</template>"
        end
        
        "#{js}\n#{templates}"
      end
    end
  end
end

Liquid::Template.register_tag('webmentions_js', Jekyll::WebmentionIO::WebmentionJSTag)