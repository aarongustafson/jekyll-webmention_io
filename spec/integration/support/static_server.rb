# frozen_string_literal: true

require 'webrick'
require_relative 'test_server'

module SmokeTest
  # Serves a built Jekyll `_site` over HTTP so the webmention client can fetch
  # the source document (for endpoint discovery and the receiver's source/target
  # verification). Plain static file serving -- nothing webmention-specific here.
  class StaticServer
    include ServerControl

    attr_reader :port, :origin

    def initialize(port, document_root)
      @port = port
      @origin = "http://127.0.0.1:#{port}"
      @server = WEBrick::HTTPServer.new(
        {
          BindAddress: '127.0.0.1',
          Port: port,
          DocumentRoot: document_root,
        }.merge(ServerControl.quiet_options)
      )
    end
  end
end
