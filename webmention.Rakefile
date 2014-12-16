desc "Trigger webmentions"
task :webmention do
  # Caches
  webmention_cache = '.webmention-cache'    # generic caching directory
  FileUtils.mkdir_p( webmention_cache )
  cache_all_webmentions = "#{webmention_cache}/webmentions.yml"
  cache_sent_webmentions = "#{webmention_cache}/sent_webmentions.yml"
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
      targets.each do |target|
        if target and ! sent_webmentions[source].find_index( target )
          if target.index( "//" ) == 0
            target  = "http:#{target}"
          end
          endpoint = `curl -s --location "#{target}" | grep 'rel="webmention"'`
          if endpoint
            endpoint.scan(/href="([^"]+)"/) do |endpoint_url|
              endpoint_url = endpoint_url[0]
              puts "Sending webmention of #{source} to #{endpoint_url}"
              command =  "curl -s -i -d \"source=#{source}&target=#{target}\" #{endpoint_url}"
              # puts command
              system command
            end
            sent_webmentions[source].push( target )
          end
        end
      end
    end
    File.open(cache_sent_webmentions, 'w') { |f| YAML.dump(sent_webmentions, f) }
  end
end