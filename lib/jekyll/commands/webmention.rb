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
				cached_outgoing = WebmentionIO.get_cache_file_path 'outgoing'
				cached_sent     = WebmentionIO.get_cache_file_path 'sent'
				if File.exists?(cached_outgoing)
					if File.exists?(cached_sent)
						sent = open(cached_sent) { |f| YAML.load(f) }
					else
						sent = {}
					end  # file exists (sent)
					outgoing = open(cached_outgoing) { |f| YAML.load(f) }
					outgoing.each_pair do |source, targets|
						if ! sent[source] or ! sent[source].kind_of? Array
							sent[source] = Array.new
						end
						targets.each do |target|
							if target and ! sent[source].find_index( target )
								if target.index( "//" ) == 0
									target  = "http:#{target}"
								end
								endpoint = WebmentionIO.get_webmention_endpoint( target )
								if endpoint
									endpoint.scan(/href="([^"]+)"/) do |endpoint_url|
										endpoint_url = endpoint_url[0]
										WebmentionIO.webmention( source, target, endpoint )
									end
									sent[source].push( target )
								end
							end
						end
					end
					File.open(cached_sent, 'w') { |f| YAML.dump(sent, f) }
				end # file exists (outgoing)
			end # def process
    end # WebmentionCommand
  end # Commands
end # Jekyll
