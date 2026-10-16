# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Jekyll::WebmentionIO::Webmentions do
  let(:mock_policy) { instance_double('Jekyll::WebmentionIO::WebmentionPolicy') }
  let(:mock_client) { instance_double('Jekyll::WebmentionIO::NetworkClient') }
  let(:webmentions) { described_class.new(mock_policy, mock_client) }

  # Mock response objects
  let(:error_response) { instance_double('Response', code: 400, body: '{"error": "Bad request"}') }
  let(:server_error_response) { instance_double('Response', code: 500, body: '{"error": "Internal server error"}') }

  before do
    # Default policy behavior - allow all URIs
    allow(mock_policy).to receive(:uri_ok?).and_return(true)
  end

  describe '#send_webmention' do
    let(:source) { 'https://example.com/source' }
    let(:target) { 'https://example.com/target' }

    context 'when webmention endpoint is not found' do
      before do
        allow(mock_client).to receive(:webmention_endpoint).with(target).and_return(nil)
        allow(mock_policy).to receive(:unsupported).with(target)
      end

      it 'reports the endpoint as unsupported and returns nil' do
        result = webmentions.send_webmention(source, target)

        expect(result).to be_nil
        expect(mock_policy).to have_received(:unsupported).with(target)
      end
    end

    context 'when webmention endpoint lookup raises an exception' do
      before do
        allow(mock_client).to receive(:webmention_endpoint).with(target).and_raise(StandardError.new('Network error'))
        allow(mock_policy).to receive(:failure).with(target)
      end

      it 'records a failure and returns nil' do
        result = webmentions.send_webmention(source, target)

        expect(result).to be_nil
        expect(mock_policy).to have_received(:failure).with(target)
      end
    end

    context 'when webmention endpoint is found' do
      before do
        allow(mock_client).to receive(:webmention_endpoint).with(target).and_return('https://example.com/webmention')
      end

      context 'with a successful response (200, 201, 202)' do
        before do
          allow(mock_policy).to receive(:success).with(target)
        end

        it 'records a success for every 2xx code and returns the response body' do
          responses = [200, 201, 202].map do |code|
            response = instance_double('Response', code: code, body: '{"status": "success"}')
            allow(mock_client).to receive(:send_webmention).with(source, target).and_return(response)

            webmentions.send_webmention(source, target)
          end

          expect(responses).to eq(['{"status": "success"}'] * 3)
          expect(mock_policy).to have_received(:success).with(target).exactly(3).times
        end
      end

      context 'with error response' do
        before do
          allow(mock_client).to receive(:send_webmention).with(source, target).and_return(error_response)
          allow(mock_policy).to receive(:error).with(target)
        end

        it 'records an error and returns false' do
          result = webmentions.send_webmention(source, target)

          expect(result).to be false
          expect(mock_policy).to have_received(:error).with(target)
        end

        context 'when response body is not valid JSON' do
          let(:invalid_json_response) { instance_double('Response', code: 400, body: 'invalid json') }

          before do
            allow(mock_client).to receive(:send_webmention).with(source, target).and_return(invalid_json_response)
          end

          it 'does not raise an exception' do
            expect { webmentions.send_webmention(source, target) }.not_to raise_error
          end
        end
      end

      context 'with a transport-level error (Webmention::ErrorResponse)' do
        # A Webmention::ErrorResponse (connection failure, no endpoint found,
        # etc.) exposes neither #code nor #body, only #message and #ok?.
        let(:transport_error_response) { Webmention::ErrorResponse.new('Connection failed', nil) }

        before do
          allow(mock_client).to receive(:send_webmention).with(source, target).and_return(transport_error_response)
          allow(mock_policy).to receive(:error).with(target)
        end

        it 'records an error without raising and returns false' do
          result = nil

          expect { result = webmentions.send_webmention(source, target) }.not_to raise_error
          expect(result).to be false
          expect(mock_policy).to have_received(:error).with(target)
        end
      end
    end
  end

  describe '#get_webmentions' do
    let(:targets) { ['https://example.com/page1', 'https://example.com/page2'] }
    let(:since_id) { 12_345 }
    let(:api_response) do
      {
        'links' => [
          { 'id' => 1, 'source' => 'https://twitter.com/user/status/123', 'data' => { 'url' => 'https://example.com/mention1' } },
          { 'id' => 2, 'source' => 'https://mastodon.social/@user/456', 'data' => { 'url' => 'https://example.com/mention2' } }
        ]
      }
    end
    let(:json_body) { JSON.generate(api_response) }

    before do
      allow(mock_client).to receive(:http_get) { json_body }
      allow(Jekyll::WebmentionIO).to receive(:log)
    end

    it 'asks webmention.io for the given targets, since_id and page' do
      targets_param = 'target[]=https://example.com/page1&target[]=https://example.com/page2&'
      suffix = '&per-page=1000'
      cases = [
        [since_id, 0, "#{targets_param}since_id=12345&sort-by=published&page=0#{suffix}"],
        [nil, 0, "#{targets_param}sort-by=published&page=0#{suffix}"],
        [since_id, 2, "#{targets_param}since_id=12345&sort-by=published&page=2#{suffix}"]
      ]
      requested_uris = []

      allow(mock_client).to receive(:http_get) do |uri, _redirect_limit|
        requested_uris << uri
        json_body
      end

      cases.each { |id, page, _query| webmentions.get_webmentions(targets, id, page) }

      expect(requested_uris).to eq(
        cases.map { |_id, _page, query| "https://webmention.io/api/mentions?#{query}" }
      )
    end

    it 'returns WebmentionItem instances' do
      result = webmentions.get_webmentions(targets, since_id)
      expect(result.items).to all(be_a(Jekyll::WebmentionIO::WebmentionItem))
      expect(result.items.length).to eq(2)
    end

    it 'reports the call as successful' do
      expect(webmentions.get_webmentions(targets, since_id)).to be_success
    end

    context 'when the response reports paging' do
      before do
        api_response['paging'] = { 'per-page' => 1000, 'page' => 0, 'total' => 2500, 'total-pages' => 3 }
      end

      it 'reports the total number of pages' do
        expect(webmentions.get_webmentions(targets, since_id).total_pages).to eq(3)
      end
    end

    context 'when the response has no paging block' do
      it 'assumes a single page' do
        expect(webmentions.get_webmentions(targets, since_id).total_pages).to eq(1)
      end
    end

    context 'when the request failed' do
      before do
        allow(mock_client).to receive(:http_get).and_return(nil)
        allow(mock_policy).to receive(:failure)
      end

      it 'reports a failure with no items and does not claim none were found' do
        result = webmentions.get_webmentions(targets, since_id)

        expect(result).not_to be_success
        expect(result.items).to eq([])
        expect(Jekyll::WebmentionIO).not_to have_received(:log).with('info', 'No webmentions found.')
      end
    end

    context 'when the response has no links' do
      it 'returns no items but still reports success' do
        [{ 'links' => [] }, {}].each do |payload|
          allow(mock_client).to receive(:http_get).and_return(JSON.generate(payload))

          result = webmentions.get_webmentions(targets, since_id)

          expect(result.items).to eq([])
          expect(result).to be_success
        end
      end
    end
  end

  describe '#get_body_from_uri' do
    let(:uri) { 'https://example.com/page' }
    let(:response_body) { '<html><body>Test content</body></html>' }

    context 'when policy allows the URI' do
      before do
        allow(mock_policy).to receive(:uri_ok?).with(uri).and_return(true)
        allow(mock_client).to receive(:http_get).with(uri, 10).and_return(response_body)
        allow(mock_policy).to receive(:failure)
      end

      it 'returns the response body without recording a failure' do
        result = webmentions.get_body_from_uri(uri)

        expect(result).to eq(response_body)
        expect(mock_policy).not_to have_received(:failure)
      end
    end

    context 'when policy does not allow the URI' do
      before do
        allow(mock_policy).to receive(:uri_ok?).with(uri).and_return(false)
        allow(mock_client).to receive(:http_get)
      end

      it 'returns false without making an HTTP request' do
        result = webmentions.get_body_from_uri(uri)

        expect(result).to be false
        expect(mock_client).not_to have_received(:http_get)
      end
    end

    context 'when HTTP request returns nil' do
      before do
        allow(mock_policy).to receive(:uri_ok?).with(uri).and_return(true)
        allow(mock_client).to receive(:http_get).with(uri, 10).and_return(nil)
        allow(mock_policy).to receive(:failure).with(uri)
      end

      it 'records a failure and returns false' do
        result = webmentions.get_body_from_uri(uri)

        expect(result).to be false
        expect(mock_policy).to have_received(:failure).with(uri)
      end
    end
  end
end
