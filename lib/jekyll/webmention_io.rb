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
require 'string_inflection'

module Jekyll
  class WebmentionIO
    @logger_prefix = '[jekyll-webmention_io]'

    # @jekyll_config = Jekyll.configuration({ 'quiet' => true })
    @jekyll_config = Jekyll.configuration({})
    @config = @jekyll_config['webmentions']

    @api_url = 'https://webmention.io/api'
    @api_endpoint = @api_url
    @api_suffix = ''

    # Set up the cache folder & files
    cache_folder = @config['cache_folder'] || '.cache'
    Dir.mkdir(cache_folder) unless File.exist?(cache_folder)
    file_prefix = ''
    file_prefix = 'webmention_io_' unless cache_folder.include? 'webmention'
    @cache_files = {
      'incoming' => "#{cache_folder}/#{file_prefix}received.yml",
      'outgoing' => "#{cache_folder}/#{file_prefix}queued.yml",
      'sent'     => "#{cache_folder}/#{file_prefix}sent.yml",
      'bad_uris' => "#{cache_folder}/#{file_prefix}bad_uris.yml"
    }
    @cache_files.each do |_key, file|
      File.open(file, 'w') { |f| YAML.dump({}, f) } unless File.exist?(file)
    end

    @types = %w[likes links posts replies reposts]

    # Attributes
    class << self
      attr_reader :config
    end

    class << self
      attr_reader :jekyll_config
    end

    class << self
      attr_reader :cache_files
    end

    class << self
      attr_reader :types
    end

    def self.get_cache_file_path(key)
      path = false
      path = @cache_files[key] if @cache_files.key? key
      path
    end

    # API helpers
    # def uri_params_for(api_params)
    #  api_params.keys.sort.map do |k|
    #    "#{CGI::escape(k)}=#{CGI::escape(api_params[k])}"
    #  end.join('&')
    # end

    def self.set_api_endpoint(path)
      @api_endpoint = "#{@api_url}/#{path}"
    end

    def self.set_api_suffix(suffix)
      @api_suffix = suffix
    end

    def self.get_response(api_params)
      api_params << @api_suffix
      source = get_uri_source(@api_endpoint + "?#{api_params}")
      if source
        JSON.parse(source)
      else
        ''
      end
    end

    def self.get_webmention_endpoint(uri)
      log 'info', "Looking for webmention endpoint at #{uri}"
      `curl -s --location "#{uri}" | grep 'rel="webmention"'`
    end

    def self.webmention(source, target, endpoint)
      log 'info', "Sending webmention of #{source} to #{endpoint}"
      `curl -s -i -d \"source=#{source}&target=#{target}\" -o /dev/null #{endpoint}`
    end

    # Utilities
    # def key_exists(hash, test_key)
    #   if hash.is_a? Hash
    #     hash.each do |key, value|
    #       if test_key == key
    #         return true
    #       # nest
    #       elsif value.is_a? Hash
    #         if key_exists value, test_key
    #           return true
    #         end
    #       end
    #     end
    #   end
    #   return false
    # end

    # Connections
    def self.is_uri_ok(uri)
      uri = URI.parse(URI.encode(uri))
      now = Time.now.to_s
      bad_uris = open(@cache_files['bad_uris']) { |f| YAML.safe_load(f) }
      if bad_uris.key? uri.host
        last_checked = DateTime.parse(bad_uris[uri.host])
        cache_bad_uris_for = @config['cache_bad_uris_for'] || 1 # in days
        recheck_at = last_checked.next_day(cache_bad_uris_for).to_s
        return false if recheck_at > now
      end
      true
    end

    # Cache bad URLs for a bit
    def self.uri_is_not_ok(uri)
      cache_file = @cache_files['bad_uris']
      bad_uris = open(cache_file) { |f| YAML.safe_load(f) }
      bad_uris[uri.host] = Time.now.to_s
      File.open(cache_file, 'w') { |f| YAML.dump(bad_uris, f) }
    end

    def self.get_uri_source(uri, redirect_limit = 10, original_uri = false)
      original_uri ||= uri
      return false unless is_uri_ok(uri)
      if redirect_limit > 0
        uri = URI.parse(URI.encode(uri))
        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = 10
        if uri.scheme == 'https'
          http.use_ssl = true
          http.ssl_version = :TLSv1
          http.ciphers = 'ALL:!ADH:!EXPORT:!SSLv2:RC4+RSA:+HIGH:+MEDIUM:-LOW'
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end
        begin
          request = Net::HTTP::Get.new(uri.request_uri)
          response = http.request(request)
        rescue SocketError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError, OpenSSL::SSL::SSLError => e
          log 'warn', "Got an error checking #{original_uri}: #{e}"
          uri_is_not_ok(uri)
          return false
        end
        case response
        when Net::HTTPSuccess then
          return response.body.force_encoding('UTF-8')
        when Net::HTTPRedirection then
          redirect_to = URI.parse(URI.encode(response['location']))
          redirect_to = redirect_to.relative? ? "#{uri.scheme}://#{uri.host}" + redirect_to.to_s : redirect_to.to_s
          return get_uri_source(redirect_to, redirect_limit - 1, original_uri)
        else
          uri_is_not_ok(uri)
          return false
        end
      else
        log 'warn', "too many redirects for #{original_uri}" if original_uri
        uri_is_not_ok(uri)
        return false
      end
    end

    def self.log(type, message)
      Jekyll.logger.method(type).call("#{@logger_prefix} #{message}")
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
