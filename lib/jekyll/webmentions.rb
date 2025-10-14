# frozen_string_literal: true

require_relative 'network_client'

module Jekyll
  module WebmentionIO
    class Webmentions
      attr_writer :api_suffix

      # Initializes a Webmention.io client, taking a WebmentionPolicy instance
      # that is being used to control retry behaviour, a NetworkClient instance
      # that is used to perform low-level network operations, and a set of
      # parameters that specifies the endpoint URL, path, and query parameters
      # to use.
      def initialize(policy, client = NetworkClient.new, url = 'https://webmention.io/api', path = 'mentions', suffix = '&perPage=9999')
        @policy = policy
        @client = client

        @api_endpoint = "#{url}/#{path}"
        @api_suffix = suffix
      end

      # Sends a webmention from the source URI to the specified target URI.
      # Wraps up the logic for looking up the webmention endpoint, sending
      # the webmention, and parsing the response.
      #
      # Depending on the success or failure of the request, also updates
      # the supplied retry policy to reflect the state of the webmention
      # target endpoint.
      def send_webmention(source, target)
        return nil if !webmention_endpoint?(URI::Parser.new.escape(target))

        Jekyll::WebmentionIO.log 'info', "Sending webmention of #{target} in #{source}"
        # return `curl -s -i -d \"source=#{source}&target=#{target}\" -o /dev/null #{endpoint}`
        response = @client.send_webmention(source, target)

        case response.code
        when 200, 201, 202
          Jekyll::WebmentionIO.log 'info', 'Webmention successful!'
          @policy.success(target)
          response.body
        else
          Jekyll::WebmentionIO.log 'info', response.inspect
          Jekyll::WebmentionIO.log 'info', 'Webmention failed, but will remain queued for next time'

          if response.body
            begin
              body = JSON.parse(response.body)

              if body.key? 'error'
                Jekyll::WebmentionIO.log 'msg', "Endpoint returned error: #{body['error']}"
              end
            rescue
            end
          end

          @policy.error(target)
          false
        end
      end

      # Reaches out to the webmention.io API to retrieve any new webmentions
      # for the supplied set of target URIs, each of which is expected to
      # be aliases or equivalent URLs for the same resource (e.g. legacy URLs,
      # redirected URLs, etc).
      #
      # The API returns JSON response containing, among other things, a
      # `links` key that's mapped to an array of originating source URLs
      # for any webmentions sent to the target.
      #
      # The method returns a list of WebmentionItem instances for each of
      # the supplied URLs.
      def get_webmentions(targets, since_id)
        api_params = targets.collect { |v| "target[]=#{v}" }.join('&')
        api_params << "&since_id=#{since_id}" if since_id
        api_params << '&sort-by=published'

        response = get_webmention_io_response(api_params)

        links = response['links'] || []

        if links.empty?
          WebmentionIO.log 'info', 'No webmentions found.'
        else
          WebmentionIO.log 'info', "Here’s what we got back:\n\n#{response.inspect}\n\n"
        end

        links.reverse.map { |wm| WebmentionIO::WebmentionItem.new(wm) }
      end

      # High-level wrapper method for making an HTTP GET call that respects
      # redirects.
      #
      # Critically, this method also updates the supplied WebmentionPolicy
      # depending on whether the call succeeds or fails.
      def get_body_from_uri(uri, redirect_limit = 10)
        return false unless @policy.uri_ok?(uri)

        response = @client.http_get(uri, redirect_limit)

        if response.nil?
          @policy.failure(uri)

          false
        else
          response
        end
      end

      private

      # Gets the webmention endpoint for the supplied URI, while updating
      # the WebmentionPolicy instance depending on the result of the
      # attempt.
      def webmention_endpoint?(uri)
        begin
          endpoint = @client.webmention_endpoint(uri)

          unless endpoint
            Jekyll::WebmentionIO.log('info', "Could not find a webmention endpoint at #{uri}")
            @policy.unsupported(uri)
          end
        rescue StandardError => e
          Jekyll::WebmentionIO.log 'info', "Endpoint lookup failed for #{uri}: #{e.message}"
          @policy.failure(uri)
          endpoint = nil
        end

        !endpoint.nil?
      end

      # Helper method for making a suitable call to the webmention.io
      # API by constructing the request using the configured URL,
      # path, and query attributes.
      def get_webmention_io_response(api_params)
        api_params << @api_suffix
        url = URI::Parser.new.escape("#{@api_endpoint}?#{api_params}")
        Jekyll::WebmentionIO.log 'info', "Sending request to #{url}."
        source = get_body_from_uri(url)
        if source
          JSON.parse(source)
        else
          {}
        end
      end
    end
  end
end
