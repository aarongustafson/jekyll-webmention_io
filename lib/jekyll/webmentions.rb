# frozen_string_literal: true
require "webmention"
require "indieweb/endpoints"

module Jekyll
  module WebmentionIO
    class Webmentions
      attr_writer :api_suffix

      def initialize(policy, url = "https://webmention.io/api", path = "mentions", suffix = "&perPage=9999")
        @policy = policy

        @api_endpoint = "#{url}/#{path}"
        @api_suffix = "&perPage=9999"
      end

      def send_webmention(source, target)
        return nil if !webmention_endpoint?(URI::Parser.new.escape(target))

        Jekyll::WebmentionIO.log "info", "Sending webmention of #{target} in #{source}"
        # return `curl -s -i -d \"source=#{source}&target=#{target}\" -o /dev/null #{endpoint}`
        response = Webmention.send_webmention(source, target)

        case response.code
        when 200, 201, 202
          Jekyll::WebmentionIO.log "info", "Webmention successful!"
          @policy.success(target)
          response.body
        else
          Jekyll::WebmentionIO.log "info", response.inspect
          Jekyll::WebmentionIO.log "info", "Webmention failed, but will remain queued for next time"

          if response.body
            begin
              body = JSON.parse(response.body)

              if body.key? "error"
                Jekyll::WebmentionIO.log "msg", "Endpoint returned error: #{body['error']}"
              end
            rescue
            end
          end

          @policy.error(target)
          false
        end
      end

      def get_webmentions(targets, since_id)
        api_params = targets.collect { |v| "target[]=#{v}" }.join("&")
        api_params << "&since_id=#{since_id}" if since_id
        api_params << "&sort-by=published"

        get_webmention_io_response(api_params)
      end

      # Connections
      def get_uri_source(uri, redirect_limit = 10, original_uri = false)
        original_uri ||= uri
        return false unless @policy.uri_ok?(uri)

        if redirect_limit.positive?
          response = get_http_response(uri)
          case response
          when Net::HTTPSuccess then
            return response.body.force_encoding("UTF-8")
          when Net::HTTPRedirection then
            redirect_to = URI::Parser.new.parse(response["location"])
            redirect_to = redirect_to.relative? ? "#{original_uri.scheme}://#{original_uri.host}" + redirect_to.to_s : redirect_to.to_s
            return get_uri_source(redirect_to, redirect_limit - 1, original_uri)
          else
            @policy.failure(uri)
            return false
          end
        else
          Jekyll::WebmentionIO.log("warn", "too many redirects for #{original_uri}") if original_uri
          @policy.failure(uri)
          return false
        end
      end

      private

      def webmention_endpoint?(uri)
        # log "info", "Looking for webmention endpoint at #{uri}"
        begin
          endpoint = IndieWeb::Endpoints.get(uri)[:webmention]
          unless endpoint
            Jekyll::WebmentionIO.log("info", "Could not find a webmention endpoint at #{uri}")
            @policy.unsupported(uri)
          end
        rescue StandardError => e
          Jekyll::WebmentionIO.log "info", "Endpoint lookup failed for #{uri}: #{e.message}"
          @policy.failure(uri)
          endpoint = nil
        end
        !endpoint.nil?
      end

      def get_webmention_io_response(api_params)
        api_params << @api_suffix
        url = URI::Parser.new.escape("#{@api_endpoint}?#{api_params}")
        Jekyll::WebmentionIO.log "info", "Sending request to #{url}."
        source = get_uri_source(url)
        if source
          JSON.parse(source)
        else
          {}
        end
      end

      def get_http_response(uri)
        uri = URI::Parser.new.parse(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = 10

        if uri.scheme == "https"
          http.use_ssl = true
          http.ciphers = "ALL:!ADH:!EXPORT:!SSLv2:RC4+RSA:+HIGH:+MEDIUM:-LOW"
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end

        begin
          request  = Net::HTTP::Get.new(uri.request_uri)
          response = http.request(request)
          return response
        rescue *EXCEPTIONS => e
          Jekyll::WebmentionIO.log "warn", "Got an error checking #{uri}: #{e}"
          @policy.failure(uri)
          return false
        end
      end
    end
  end
end
