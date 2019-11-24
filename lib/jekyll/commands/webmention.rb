# frozen_string_literal: true

require "json"

module Jekyll
  module WebmentionIO
    module Commands
      class WebmentionCommand < Command
        def self.init_with_program(prog)
          prog.command(:webmention) do |c|
            c.syntax "webmention"
            c.description "Sends queued webmentions"

            c.action { |args, options| process args, options }
          end
        end

        def self.process(_args = [], options = {})
          options = configuration_from_options(options)
          WebmentionIO.bootstrap(Jekyll::Site.new(options))

          if File.exist? WebmentionIO.cache_file("sent.yml")
            WebmentionIO.log "error", "Your outgoing webmentions queue needs to be upgraded. Please re-build your project."
          end

          WebmentionIO.log "msg", "Getting ready to send webmentions (this may take a while)."

          count = 0
          max_attempts = WebmentionIO.max_attempts()
          cached_outgoing = WebmentionIO.get_cache_file_path "outgoing"
          if File.exist?(cached_outgoing)
            outgoing = WebmentionIO.load_yaml(cached_outgoing)
            outgoing.each do |source, targets|
              targets.each do |target, response|
                # skip ones we’ve handled
                next unless response == false or response.instance_of? Integer

                # convert protocol-less links
                if target.index("//").zero?
                  target = "http:#{target}"
                end

                # skip bad URLs
                next unless WebmentionIO.uri_ok?(target)

                # give up if we've attempted this too many times
                response = (response || 0) + 1

                if ! max_attempts.nil? and response > max_attempts
                  outgoing[source][target] = ""
                  WebmentionIO.log "msg", "Giving up sending from #{source} to #{target}."
                  next
                else
                  outgoing[source][target] = response
                end

                # get the endpoint
                endpoint = WebmentionIO.get_webmention_endpoint(target)
                next unless endpoint

                # get the response
                response = WebmentionIO.webmention(source, target, endpoint)
                next unless response

                # capture JSON responses in case site wants to do anything with them
                begin
                  response = JSON.parse response
                rescue JSON::ParserError
                  response = ""
                end
                outgoing[source][target] = response
                count += 1
              end
            end
            WebmentionIO.dump_yaml(cached_outgoing, outgoing)
            WebmentionIO.log "msg", "#{count} webmentions sent."
          end # file exists (outgoing)
        end # def process
      end # WebmentionCommand
    end # Commands
  end # WebmentionIO
end # Jekyll
