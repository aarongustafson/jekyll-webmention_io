# frozen_string_literal: true

require 'webrick'
require_relative 'test_server'

module SmokeTest
  # A throwaway site for the NetworkClient specs: pages that succeed, redirect
  # (relative and absolute Location, and one with no Location at all), fail, and
  # loop. Served over real HTTP so the Net::HTTP response classification in
  # NetworkClient#perform_http_request -- the part unit tests stub out -- is
  # exercised for real.
  class RedirectServer
    include ServerControl

    attr_reader :port, :origin

    def initialize(port)
      @port = port
      @origin = "http://127.0.0.1:#{port}"
      @server = WEBrick::HTTPServer.new(
        {
          BindAddress: '127.0.0.1',
          Port: port,
        }.merge(ServerControl.quiet_options)
      )

      mount_routes
    end

    private

    def mount_routes
      @server.mount_proc('/ok') do |_request, response|
        respond(response, 200, 'ok')
      end

      @server.mount_proc('/moved') do |_request, response|
        respond(response, 302, nil, 'location' => '/ok')
      end

      # A relative Location from a nested path: resolving it against the
      # requested URI is what keeps the directory intact.
      @server.mount_proc('/deep/page') do |_request, response|
        respond(response, 302, nil, 'location' => '../ok')
      end

      @server.mount_proc('/absolute') do |_request, response|
        respond(response, 302, nil, 'location' => "#{@origin}/ok")
      end

      # Protocol-relative Location: no scheme at all, so the client has to
      # inherit it from the URI it requested.
      @server.mount_proc('/protocol-relative') do |_request, response|
        respond(response, 302, nil, 'location' => "//127.0.0.1:#{@port}/ok")
      end

      @server.mount_proc('/loop') do |_request, response|
        respond(response, 302, nil, 'location' => '/loop')
      end

      @server.mount_proc('/no-location') do |_request, response|
        respond(response, 302, nil, {})
      end

      @server.mount_proc('/gone') do |_request, response|
        respond(response, 404, 'gone')
      end
    end

    def respond(response, status, body, headers = {})
      response.status = status
      response.body = body
      headers.each { |name, value| response[name] = value }
    end
  end
end
