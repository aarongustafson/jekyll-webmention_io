require "webmention"
require "indieweb/endpoints"
require "net/http"
require "openssl"

module Jekyll
  module WebmentionIO
    class NetworkClient
      module HTTPStatus
        SUCCESS = 0
        FAILURE = 1
      end

      EXCEPTIONS = [
        SocketError, Timeout::Error,
        Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED, EOFError,
        Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError,
        OpenSSL::SSL::SSLError,
      ].freeze

      # Send a webmention to the target URL from the source URL indicated.
      #
      # Returns a response object with a code attribute indicating the numeric
      # HTTP response code, and a body attribute containing the response
      # payload. Webmentions contain no specific spec for what that response
      # must look like, though services like webmention.io return JSON.
      def send_webmention(source, target)
        Webmention.send_webmention(source, target)
      end

      # For a give URI on a site, returns the specific URI to be used when
      # posting webmentions to that site.
      #
      # e.g. for "https://www.site.com" this might return
      # "https://www.site.com/webmentions"
      def webmention_endpoint(uri)
        IndieWeb::Endpoints.get(uri)[:webmention]
      end

      # A helper function which performs an HTTP GET operate on the target
      # URI while handling 302 redirects (up to a specific limit).
      #
      # Returns the body if a 200 OK was received or nil if an error occurred
      # (including if the redirect limit was reached).
      def http_get(uri, redirect_limit, original_uri = false)
        if !redirect_limit.positive?
          Jekyll::WebmentionIO.log('warn', "too many redirects for #{original_uri}") if original_uri

          return nil
        end

        original_uri ||= uri

        response = perform_http_request(uri)

        case response[:status]
        when HTTPStatus::SUCCESS
          response[:body]

        when HTTPStatus::REDIRECTION
          redirect_to =
            if response[:body].relative?
              "#{original_uri.scheme}://#{original_uri.host}" + response.body.to_s
            else
              response[:body].to_s
            end

          http_get(redirect_to, redirect_limit - 1, original_uri)
        end
      end

      private

      def perform_http_request(uri)
        uri = URI::Parser.new.parse(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = 10

        if uri.scheme == 'https'
          http.use_ssl = true
          http.ciphers = 'ALL:!ADH:!EXPORT:!SSLv2:RC4+RSA:+HIGH:+MEDIUM:-LOW'
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end

        begin
          request = Net::HTTP::Get.new(uri.request_uri)
          response = http.request(request)

          case response
          when Net::HTTPSuccess
            { status: HTTPStatus::SUCCESS, body: response.body.force_encoding('UTF-8') }

          when Net::HTTPRedirection
            { status: HTTPStatus::REDIRECTION, body: URI::Parser.new.parse(response['location']) }

          else
            { status: HTTPStatus::FAILURE }
          end
        rescue *EXCEPTIONS => e
          Jekyll::WebmentionIO.log 'warn', "Got an error checking #{uri}: #{e}"

          { status: HTTPStatus::FAILURE }
        end
      end
    end
  end
end
