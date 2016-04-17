#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT

module Jekyll
  module WebmentionIo

    class WebmentionCommand < Jekyll::Command
      class << self
        def init_with_program(p)
          p.command(:webmention) do |c|
            c.alias(:webmentions)
            c.version(Jekyll::WebmentionIo::VERSION)

            c.syntax "webmention [--dry-run]"
            c.description 'Notify any mentioned URLs that offer webmention endpoints'

            c.option 'dryrun', '--dry-run', 'Process webmentions without actually sending the notification'
            c.option 'verbose', '--verbose', 'Output verbose processing details'

            c.action do |args, options|
              cache = WEBMENTION_CACHE_DIR
              cache_all_webmentions = "#{cache}/webmentions.yml"
              cache_sent_webmentions = "#{cache}/webmentions_sent.yml"

              if File.exists?(cache_all_webmentions)
                if File.exists?(cache_sent_webmentions)
                  sent_webmentions = open(cache_sent_webmentions) { |f| YAML.load(f) }
                else
                  sent_webmentions = {}
                end
                all_webmentions = open(cache_all_webmentions) { |f| YAML.load(f) }
                all_webmentions.each_pair do |source, targets|
                  if ! sent_webmentions[source] or ! sent_webmentions[source].kind_of?(Array)
                    sent_webmentions[source] = Array.new
                  end

                  c.logger.info "Checking #{targets.length} URLs for webmention endpoints.."
                  targets.each do |target|
                    if target and ! sent_webmentions[source].find_index( target )
                      if target.index( "//" ) == 0
                        target  = "http:#{target}"
                      end
                      c.logger.info "    #{target}" if options['verbose']
                      endpoint = `curl -s --location "#{target}" | grep 'rel="webmention"'`
                      if endpoint
                        endpoint.scan(/href="([^"]+)"/) do |endpoint_url|
                          endpoint_url = endpoint_url[0]
                          c.log.info "    Sending webmention of #{source} to #{endpoint_url}"
                          command =  "curl -s -i -d \"source=#{source}&target=#{target}\" -o /dev/null #{endpoint_url}"
                          
                          if options['dryrun']
                            c.log.info "(dry-run) #{command}"
                          else
                            system command
                          end
                        end
                        sent_webmentions[source].push( target )
                      end
                    end
                  end
                end
                File.open(cache_sent_webmentions, 'w') { |f| YAML.dump(sent_webmentions, f) }
              end

            end
          end
        end
      end
    end

  end
end
