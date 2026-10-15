# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Jekyll::WebmentionIO::NetworkClient do
  let(:client) { described_class.new }
  let(:status) { described_class::HTTPStatus }
  let(:page) { 'https://example.com/dir/page' }

  # #perform_http_request is stubbed throughout: these examples cover how
  # #http_get turns the statuses it reports into bodies, redirects, and nils.
  # The real response classification is covered over the wire in
  # spec/integration/network_client_spec.rb.
  def respond_with(*responses)
    allow(client).to receive(:perform_http_request).and_return(*responses)
  end

  # Drives a single redirect hop and returns the body #http_get produced plus
  # every URI it asked for, so both halves of the resolution can be asserted.
  def follow_a_redirect(location)
    requested = []
    allow(client).to receive(:perform_http_request) do |uri|
      requested << uri.to_s

      if requested.length == 1
        { status: status::REDIRECTION, body: URI.parse(location) }
      else
        { status: status::SUCCESS, body: 'final' }
      end
    end

    [client.http_get(page, 10), requested]
  end

  describe '#http_get' do
    context 'when the request succeeds' do
      it 'returns the response body' do
        respond_with({ status: status::SUCCESS, body: 'hello' })

        expect(client.http_get(page, 10)).to eq('hello')
      end
    end

    context 'when the request fails' do
      it 'returns nil' do
        respond_with({ status: status::FAILURE })

        expect(client.http_get(page, 10)).to be_nil
      end
    end

    context 'when the request redirects' do
      it 'follows an absolute redirect on the same host' do
        body, requested = follow_a_redirect('https://example.com/moved')

        expect(body).to eq('final')
        expect(requested).to eq([page, 'https://example.com/moved'])
      end

      it 'takes an absolute redirect on another host verbatim' do
        body, requested = follow_a_redirect('https://other.example/moved')

        expect(body).to eq('final')
        expect(requested).to eq([page, 'https://other.example/moved'])
      end

      it 'resolves a relative redirect against the URI it just requested' do
        body, requested = follow_a_redirect('../moved')

        expect(body).to eq('final')
        expect(requested).to eq([page, 'https://example.com/moved'])
      end

      it 'accepts an already-parsed URI' do
        respond_with({ status: status::SUCCESS, body: 'hello' })

        expect(client.http_get(URI.parse(page), 10)).to eq('hello')
      end

      it 'gives up once the redirect limit is exhausted' do
        respond_with({ status: status::REDIRECTION, body: URI.parse('https://example.com/loop') })

        expect(client.http_get(page, 3)).to be_nil
        expect(client).to have_received(:perform_http_request).exactly(3).times
      end
    end
  end
end
