# frozen_string_literal: true

require 'json'
require 'net/http'
require 'time'
require 'webrick'
require_relative 'test_server'

module SmokeTest
  # A self-contained stand-in for both halves of the webmention.io service, so
  # the integration suite never has to touch the network:
  #
  #   * a spec-compliant Webmention *receiver* at POST /webmention -- it does
  #     real source-links-to-target verification before accepting a mention; and
  #   * a webmention.io-compatible *read API* at GET /api/mentions, returning
  #     received mentions in the JSON shape WebmentionItem expects.
  #
  # Receiving and then serving the same mentions back is what lets the smoke
  # test exercise a genuine round trip rather than a mocked handshake.
  #
  # See https://www.w3.org/TR/webmention/ and
  # https://github.com/aaronpk/webmention.io#api.
  class WebmentionHub
    include ServerControl

    # Canned content echoed back in the read API so the spec has a stable string
    # to assert against in the rendered page.
    MENTION_CONTENT = 'This webmention was delivered by the smoke-test hub.'
    MENTION_AUTHOR = 'Smoke Tester'

    Mention = Struct.new(:id, :source, :target, :verified_at, keyword_init: true)

    attr_reader :port, :origin, :endpoint, :api_url

    def initialize(port)
      @port = port
      @origin = "http://127.0.0.1:#{port}"
      @endpoint = "#{@origin}/webmention"
      @api_url = "#{@origin}/api"

      @mentions = []
      @mutex = Mutex.new
      @next_id = 1000

      @server = WEBrick::HTTPServer.new(
        {
          BindAddress: '127.0.0.1',
          Port: port,
        }.merge(ServerControl.quiet_options)
      )
      @server.mount_proc('/webmention') { |req, res| receive(req, res) }
      @server.mount_proc('/api/mentions') { |req, res| serve_api(req, res) }
    end

    # A thread-safe snapshot of everything the receiver has accepted.
    def mentions
      @mutex.synchronize { @mentions.dup }
    end

    # Inject a mention directly, bypassing the HTTP receive path. Lets the
    # read-API/render test stand on its own rather than depending on the send
    # test having run (and succeeded) first.
    def seed(source:, target:)
      record(source, target)
      self
    end

    # Forget every recorded mention so one example can't leak state into the
    # next.
    def clear
      @mutex.synchronize { @mentions.clear }
    end

    private

    # POST /webmention -- the receiver endpoint advertised by target pages.
    def receive(request, response)
      return respond(response, 405, 'error' => 'method not allowed') unless request.request_method == 'POST'

      source = request.query['source']
      target = request.query['target']

      return respond(response, 400, 'error' => 'source and target are required') unless source && target
      return respond(response, 400, 'error' => 'source does not link to target') unless source_links_to_target?(source, target)

      record(source, target)
      respond(response, 201, 'result' => 'accepted')
    end

    # GET /api/mentions -- the webmention.io read API used at build time.
    def serve_api(request, response)
      wanted = requested_targets(request.query_string)
      links = mentions.select { |mention| wanted.include?(mention.target) }.map { |mention| link_for(mention) }

      respond(response, 200, 'links' => links)
    end

    def record(source, target)
      @mutex.synchronize do
        @next_id += 1
        @mentions << Mention.new(id: @next_id, source: source, target: target, verified_at: Time.now)
      end
    end

    # Spec verification: fetch the source document and confirm it actually links
    # to the target. This is what makes leg A a real test -- the plugin has to
    # emit a page that genuinely mentions the target.
    def source_links_to_target?(source, target)
      body = http_get(source)
      body ? body.include?(target) : false
    end

    def http_get(url)
      response = Net::HTTP.get_response(URI(url))
      response.is_a?(Net::HTTPSuccess) ? response.body : nil
    rescue StandardError
      nil
    end

    # webmention.io repeats the target parameter as `target[]=...`. WEBrick's
    # parsed query collapses duplicate keys, so pull them straight from the raw
    # query string instead.
    def requested_targets(query_string)
      (query_string || '').split('&').filter_map do |pair|
        key, value = pair.split('=', 2)
        next unless value

        decoded_key = WEBrick::HTTPUtils.unescape(key).sub(/\[\]\z/, '')
        WEBrick::HTTPUtils.unescape(value) if decoded_key == 'target'
      end
    end

    # Shape a stored mention like a webmention.io API entry. The fields here are
    # exactly those WebmentionItem reads (see webmention_item.rb).
    def link_for(mention)
      {
        'id' => mention.id,
        'source' => mention.source,
        'target' => mention.target,
        'verified_date' => mention.verified_at.iso8601,
        'activity' => { 'type' => 'link' },
        'data' => {
          'url' => mention.source,
          'name' => 'A mention from the test hub',
          'content' => MENTION_CONTENT,
          'published_ts' => mention.verified_at.to_i,
          'author' => { 'name' => MENTION_AUTHOR, 'url' => mention.source },
        },
      }
    end

    def respond(response, status, payload)
      response.status = status
      response['Content-Type'] = 'application/json'
      response.body = JSON.generate(payload)
    end
  end
end
