module Jekyll
  module Commands
    class WebmentionCommand < Command
      def self.init_with_program(prog)
        prog.command(:webmention) do |c|
          c.syntax 'webmention'
          c.description 'Sends queued webmentions'

          c.action { |args, options| process args, options }
        end
      end

      def self.process(_args = [], _options = {})
        cached_outgoing = WebmentionIO.get_cache_file_path 'outgoing'
        cached_sent = WebmentionIO.get_cache_file_path 'sent'
        if File.exist?(cached_outgoing)
          sent = if File.exist?(cached_sent)
                   open(cached_sent) { |f| YAML.safe_load(f) }
                 else
                   {}
                 end # file exists (sent)
          outgoing = open(cached_outgoing) { |f| YAML.safe_load(f) }
          outgoing.each_pair do |source, targets|
            sent[source] = [] if !sent[source] || !sent[source].is_a?(Array)
            targets.each do |target|
              next unless target && !sent[source].find_index(target)
              target = "http:#{target}" if target.index('//') == 0
              endpoint = WebmentionIO.get_webmention_endpoint(target)
              next unless endpoint
              endpoint.scan(/href="([^"]+)"/) do |endpoint_url|
                endpoint_url = endpoint_url[0]
                WebmentionIO.webmention(source, target, endpoint)
              end
              sent[source].push(target)
            end
          end
          File.open(cached_sent, 'w') { |f| YAML.dump(sent, f) }
        end # file exists (outgoing)
      end # def process
    end # WebmentionCommand
  end # Commands
end # Jekyll
