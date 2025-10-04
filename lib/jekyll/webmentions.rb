# frozen_string_literal: true

require_relative 'network_client'

module Jekyll
  module WebmentionIO
    class Webmentions
      attr_writer :api_suffix

      def initialize(policy, client = NetworkClient.new, url = "https://webmention.io/api", path = "mentions", suffix = "&perPage=9999")
        @policy = policy
        @client = client

        @api_endpoint = "#{url}/#{path}"
        @api_suffix = suffix
      end

      def send_webmention(source, target)
        return nil if !webmention_endpoint?(URI::Parser.new.escape(target))

        Jekyll::WebmentionIO.log "info", "Sending webmention of #{target} in #{source}"
        # return `curl -s -i -d \"source=#{source}&target=#{target}\" -o /dev/null #{endpoint}`
        response = @client.send_webmention(source, target)

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

      # Returns WebmentionIO::WebmentionItem instances
      def get_webmentions(targets, since_id)
        api_params = targets.collect { |v| "target[]=#{v}" }.join("&")
        api_params << "&since_id=#{since_id}" if since_id
        api_params << "&sort-by=published"

        response = get_webmention_io_response(api_params)

        links = response["links"] || []

        if links.empty?
          WebmentionIO.log "info", "No webmentions found."
        else
          WebmentionIO.log "info", "Here’s what we got back:\n\n#{response.inspect}\n\n"
        end

        links.reverse.map { |wm| WebmentionIO::WebmentionItem.new(link) }
      end

      # Connections
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

      def webmention_endpoint?(uri)
        begin
          endpoint = @client.webmention_endpoint(uri)

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
