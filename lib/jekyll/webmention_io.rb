#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  this liquid plugin insert a webmentions into your Octopress or Jekill blog
#  using http://webmention.io/ and the following syntax:
#   
require 'jekyll/webmention_io/version'

require 'json'
require 'net/http'
require 'uri'
require 'openssl'

module Jekyll
  class WebmentionIO
    attr_reader :jekyll_config, :config

    def initialize()
      @logger_prefix = '[jekyll-webmention_io]'

      @jekyll_config = Jekyll.configuration({})
      @config = @jekyll_config['webmentions']
      
      @api_url = 'https://webmention.io/api'
      @api_endpoint = @api_url
      @api_suffix = ''
      
      # Set up the cache folder & files
      cache_folder = @config['cache_folder'] || '.cache'
      Dir.mkdir(cache_folder) unless File.exists?(cache_folder)
      cache_folder = "#{@config['cache_folder']}/webmentions"
      Dir.mkdir(cache_folder) unless File.exists?(cache_folder)
      @cache_files = {
        'incoming' => "#{cache_folder}/received.yml",
        'outgoing' => "#{cache_folder}/queued.yml",
        'sent'     => "#{cache_folder}/sent.yml",
        'bad_urls' => "#{cache_folder}/bad_urls.yml"
      }
      @cache_files.each do |key, file|
        if ! File.exists?(file)
          File.open(file, 'w') { |f| YAML.dump({}, f) }
        end
      end
    end

    # Cache access
    def get_cache_file_path( key )
      path = false
      if @cache_files.has_key? key
        path = @cache_files[key]
      end
      return path
    end

    # API helpers
    def url_params_for(api_params)
      api_params.keys.sort.map do |k|
        "#{CGI::escape(k)}=#{CGI::escape(api_params[k])}"
      end.join('&')
    end

    def set_api_endpoint(path)
      @api_endpoint = "#{@api_url}/#{path}"
    end
    
    def set_api_suffix(suffix)
      @api_suffix = suffix
    end

    def get_response(api_params)
      api_params << @api_suffix
      source = get_uri_source(@api_endpoint + "?#{api_params}")
      if source
        JSON.parse(source)
      else
        ""
      end
    end
    
    def get_webmention_endpoint( url )
      log 'info', "Looking for webmention endpoint at #{url}"
      return `curl -s --location "#{url}" | grep 'rel="webmention"'`
    end

    def webmention( source, target, endpoint )
      log 'info', "Sending webmention of #{source} to #{endpoint_url}"
      return `curl -s -i -d \"source=#{source}&target=#{target}\" -o /dev/null #{endpoint_url}`
    end

    # def lookup(context, name)
    #   lookup = context

    #   name.split(".").each do |value|
    #     lookup = lookup[value]
    #   end

    #   lookup
    # end

    # Utilities
    def key_exists(hash, test_key)
      if hash.is_a? Hash 
        hash.each do |key, value|
          if test_key == key
            return true
          # nest
          elsif value.is_a? Hash
            if key_exists value, test_key
              return true
            end
          end
        end
      end
      return false
    end
    
    # Connections
    def is_url_ok( uri )
      now = Time.now.to_s
      bad_urls = open(@cache_files['bad_urls']) { |f| YAML.load(f) }
      # puts "#{uri.host} in bad_urls? " + (bad_urls.key? uri.host).to_s
      if bad_urls.key? uri.host
        # puts "checking #{uri.host}"
        last_checked = DateTime.parse( bad_urls[uri.host] )
        cache_bad_urls_for = @config['cache_bad_urls_for'] || 1 # in days
        recheck_at = last_checked.next_day(cache_bad_urls_for).to_s
        # puts "last_checked " + last_checked.to_s
        # puts "testing " + ( last_checked + ( 60 * 60 * 24 ) ).to_s
        # puts last_checked + ( 60 * 60 * 24 ) < now
        # wait at least a day before checking again
        if recheck_at > now
          # puts "url is bad"
          # URL is bad
          return false
        end
      end
      # puts "url is AOK"
      return true
    end

    # Cache bad domains for a bit
    def domain_is_not_ok( uri )
      cache_file = @cache_files['bad_urls']
      bad_urls = open(cache_file) { |f| YAML.load(f) }
      bad_urls[uri.host] = Time.now.to_s
      File.open(cache_file, 'w') { |f| YAML.dump(bad_urls, f) }
    end
    
    def get_uri_source(uri, redirect_limit = 10, original_uri = false)
      # puts "Getting the source of #{uri}"
      original_uri = original_uri || uri
      if ! is_url_ok(uri)
        return false
      end
      if redirect_limit > 0
        uri = URI.parse(URI.encode(uri))
        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = 10
        if uri.scheme == 'https'
          http.use_ssl = true
          http.ssl_version = :TLSv1
          http.ciphers = "ALL:!ADH:!EXPORT:!SSLv2:RC4+RSA:+HIGH:+MEDIUM:-LOW"
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end
        begin
          request = Net::HTTP::Get.new(uri.request_uri)
          response = http.request(request)
        rescue SocketError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
          log 'warn', "Got an error checking #{original_uri}: #{e}"
          domain_is_not_ok(uri)
          return false
        end
        case response
          when Net::HTTPSuccess then
            return response.body.force_encoding('UTF-8')
          when Net::HTTPRedirection then
            # puts "Location redirect to #{response['location']}"
            redirect_to = URI.parse(URI.encode(response['location']))
            redirect_to = redirect_to.relative? ? "#{uri.scheme}://#{uri.host}" + redirect_to.to_s : redirect_to.to_s
            # puts "redirecting to #{redirect_to}"
            return get_uri_source(redirect_to, redirect_limit - 1, original_uri)
          else
            domain_is_not_ok(uri)
            return false
        end
      else
        if original_uri
          log 'warn', "too many redirects for #{original_uri}"
        end
        domain_is_not_ok(uri)
        return false
      end
    end

    def log( type, message )
      Jekyll.logger.method(type).call( "#{@logger_prefix} #{message}" )
    end

  end
end

# Load all the bits
Dir[File.dirname(__FILE__) + '/commands/*.rb'].each do |file|
  require file
end
Dir[File.dirname(__FILE__) + '/generators/*.rb'].each do |file|
  require file
end
Dir[File.dirname(__FILE__) + '/tags/*.rb'].each do |file|
  require file
end