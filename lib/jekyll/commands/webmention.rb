require 'json'

module Jekyll
  module Commands
    class WebmentionCommand < Command
      def self.init_with_program( prog )
        prog.command(:webmention) do |c|
          c.syntax 'webmention'
          c.description 'Sends queued webmentions'
          
          c.action { |args, options| process args, options }
        end
      end

      def self.process( args=[], options={} )
        cached_outgoing = Jekyll::WebmentionIO::get_cache_file_path 'outgoing'
        if File.exists?(cached_outgoing)
          outgoing = open(cached_outgoing) { |f| YAML.load(f) }
          outgoing.each do |source, targets|
            targets.each do |target, response|
              if response === false
                if target.index( "//" ) == 0
                  target  = "http:#{target}"
                end
                endpoint = Jekyll::WebmentionIO::get_webmention_endpoint( target )
                if endpoint
                  response = Jekyll::WebmentionIO::webmention( source, target, endpoint )
                  if response
                    outgoing[source][target] = JSON.parse response.body
                  end
                end
              end
            end
          end
          File.open(cached_outgoing, 'w') { |f| YAML.dump(outgoing, f) }
        end # file exists (outgoing)
      end # def process
    end # WebmentionCommand
  end # Commands
end # Jekyll
