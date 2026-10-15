# frozen_string_literal: true

require 'spec_helper'
require_relative 'support/redirect_server'

# NetworkClient against a real HTTP server. The unit suite stubs
# #perform_http_request, which is how the redirect branch shipped referencing a
# status constant that was never defined; these examples go over the wire
# instead.
RSpec.describe Jekyll::WebmentionIO::NetworkClient, :integration do
  before(:all) do
    @server = SmokeTest::RedirectServer.new(SmokeTest.free_port).start
  end

  after(:all) { @server&.stop }

  subject(:client) { described_class.new }

  def url(path)
    "#{@server.origin}#{path}"
  end

  it 'returns the body of a successful response' do
    expect(client.http_get(url('/ok'), 10)).to eq('ok')
  end

  it 'follows a redirect with a relative Location' do
    expect(client.http_get(url('/moved'), 10)).to eq('ok')
  end

  it 'follows a redirect with an absolute Location' do
    expect(client.http_get(url('/absolute'), 10)).to eq('ok')
  end

  it 'follows a protocol-relative Location using the requested scheme' do
    expect(client.http_get(url('/protocol-relative'), 10)).to eq('ok')
  end

  it 'resolves a relative Location against the requested directory' do
    expect(client.http_get(url('/deep/page'), 10)).to eq('ok')
  end

  it 'accepts an already-parsed URI' do
    expect(client.http_get(URI.parse(url('/ok')), 10)).to eq('ok')
  end

  it 'returns nil for a failing response instead of raising' do
    expect(client.http_get(url('/gone'), 10)).to be_nil
  end

  it 'returns nil once a redirect loop exhausts the limit' do
    expect(client.http_get(url('/loop'), 3)).to be_nil
  end

  it 'returns nil for a redirect with no Location header' do
    expect(client.http_get(url('/no-location'), 3)).to be_nil
  end
end
