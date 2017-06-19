module Jekyll
  module Commands
    class WebmentionCommand < Command
			include WebmentionIO

      class << self
        def init_with_program(prog)
          prog.command(:webmention) do |c|
						c.description "Send webmentions"

						add_build_options(c)

            c.action do |args, options|
              puts options.inspect

						c.action do |args, opts|
              opts["serving"] = false
              Jekyll::Commands::Webmention.process(args, opts)
            end
					end
				end

				def process(args, opts)
          Jekyll.logger.adjust_verbosity(opts)
          options = configuration_from_options(opts)
          site = Jekyll::Site.new(options)

          site.reset
          site.read

					if File.exists?(@cache_files['outgoing'])
						if File.exists?(@cache_files['sent'])
							sent = open(@cache_files['sent']) { |f| YAML.load(f) }
						else
							sent = {}
						end
						outgoing = open(@cache_files['outgoing']) { |f| YAML.load(f) }
						outgoing.each_pair do |source, targets|
							if ! sent[source] or ! sent[source].kind_of?(Array)
								sent[source] = Array.new
							end
							targets.each do |target|
								if target and ! sent[source].find_index( target )
									if target.index( "//" ) == 0
										target  = "http:#{target}"
									end
									endpoint = get_webmention_endpoint( target )
									if endpoint
										endpoint.scan(/href="([^"]+)"/) do |endpoint_url|
											endpoint_url = endpoint_url[0]
											webmention( source, target, endpoint )
										end
										sent[source].push( target )
									end
								end
							end
						end
						File.open(@cache_files['sent'], 'w') { |f| YAML.dump(sent, f) }
					end
        end
      end
    end
  end
end