# frozen_string_literal: false

require "json"

module Jekyll
  module Commands
    class WebmentionCommand < Command
      def self.init_with_program(prog)
        prog.command(:webmention) do |c|
          c.syntax "webmention"
          c.description "Sends queued webmentions"

          c.action { |args, options| process args, options }
        end
      end

      def self.process(_args = [], _options = {})
        if File.exist? "#{Jekyll::WebmentionIO.cache_folder}/#{Jekyll::WebmentionIO.file_prefix}sent.yml"
          Jekyll::WebmentionIO.log "error", "Your outgoing webmentions queue needs to be upgraded. Please re-build your project."
        end
        count = 0
        cached_outgoing = Jekyll::WebmentionIO.get_cache_file_path "outgoing"
        if File.exist?(cached_outgoing)
          outgoing = open(cached_outgoing) { |f| YAML.load(f) }
          outgoing.each do |source, targets|
            targets.each do |target, response|
              next unless response == false
              if target.index("//").zero?
                target = "http:#{target}"
              end
              endpoint = Jekyll::WebmentionIO.get_webmention_endpoint(target)
              next unless endpoint
              response = Jekyll::WebmentionIO.webmention(source, target, endpoint)
              next unless response
              begin
                response = JSON.parse response
              rescue JSON::ParserError
                response = ""
              end
              outgoing[source][target] = response
              count += 1
            end
          end
          if count.positive?
            File.open(cached_outgoing, "w") { |f| YAML.dump(outgoing, f) }
          end
          Jekyll::WebmentionIO.log "info", "#{count} webmentions sent."
        end # file exists (outgoing)
      end # def process
    end # WebmentionCommand
  end # Commands
end # Jekyll
