#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  Stuff for the `head`
#

module Jekyll
  module WebmentionIO
    class WebmentionTemplatesTag < Liquid::Tag
      def render(context)
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
				
        templates
      end
    end
  end
end

Liquid::Template.register_tag('webmentions_templates', Jekyll::WebmentionIO::WebmentionTemplatesTag)