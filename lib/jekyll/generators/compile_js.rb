#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  This generator gathers webmentions of your pages
#

require 'uglifier'

module Jekyll
  class GatherWebmentions < Generator
    
    safe true
    priority :low
    
    def generate(site)
      if site.config['webmentions']['js'] == false
        Jekyll::WebmentionIO::log 'info', 'Skipping JavaScript inclusion.'
        return
      end

      source = File.join(File.dirname(File.expand_path(__FILE__)), '../assets/')
      destination = site.config['webmentions']['js']['destination'] || "#{site.config['destination']}/js";
      
      javascript = ''
      Dir["#{source}/*.js"].each do |file|
        handler = File.open(file, 'rb')
        javascript << File.read(handler)
      end

      unless site.config['webmentions']['js']['uglify'] == false
        javascript = Uglifier.compile(javascript)
      end

      File.open("#{destination}/JekyllWebmentionIO.js", 'w') { |file| file.write( javascript )  }

      Jekyll::WebmentionIO::log 'info', 'JavaScript has been written into the directory.'
    end
  end
end