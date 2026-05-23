# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Jekyll::WebmentionIO::WebmentionHeadTag do
  include_context 'webmention_io_stubs'

  let(:page) { {} }
  let(:context) { Struct.new(:page, :line_number, :registers).new(page, 1, {}) }
  let(:tag) { described_class.parse(nil, '', nil, context) }

  context 'with the default (webmention.io) endpoint' do
    before { config.parse({ 'username' => 'aaron' }) }

    it 'emits service links pointing at webmention.io' do
      head = tag.render(context)

      expect(head).to include('<link rel="dns-prefetch" href="https://webmention.io">')
      expect(head).to include('<link rel="preconnect" href="https://webmention.io">')
      expect(head).to include('<link rel="preconnect" href="ws://webmention.io:8080">')
      expect(head).to include('<link rel="pingback" href="https://webmention.io/aaron/xmlrpc">')
      expect(head).to include('<link rel="webmention" href="https://webmention.io/aaron/webmention">')
    end
  end

  context 'with a custom api_url' do
    before { config.parse({ 'api_url' => 'http://localhost:9999/api', 'username' => 'aaron' }) }

    it 'derives the service links from the configured origin' do
      head = tag.render(context)

      expect(head).to include('<link rel="dns-prefetch" href="http://localhost:9999">')
      expect(head).to include('<link rel="preconnect" href="ws://localhost:8080">')
      expect(head).to include('<link rel="pingback" href="http://localhost:9999/aaron/xmlrpc">')
      expect(head).to include('<link rel="webmention" href="http://localhost:9999/aaron/webmention">')
    end
  end
end
