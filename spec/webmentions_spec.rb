# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Jekyll::WebmentionIO::Webmentions do
  let(:mock_policy) { instance_double('Jekyll::WebmentionIO::WebmentionPolicy') }
  let(:mock_client) { instance_double('Jekyll::WebmentionIO::NetworkClient') }
  let(:webmentions) { described_class.new(mock_policy, mock_client) }

  # Mock response objects
  let(:success_response) { instance_double('Response', code: 200, body: '{"status": "success"}') }
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

      it 'returns nil' do
        result = webmentions.send_webmention(source, target)
        expect(result).to be_nil
      end

      it 'calls policy.unsupported' do
        webmentions.send_webmention(source, target)
        expect(mock_policy).to have_received(:unsupported).with(target)
      end
    end

    context 'when webmention endpoint lookup raises an exception' do
      before do
        allow(mock_client).to receive(:webmention_endpoint).with(target).and_raise(StandardError.new('Network error'))
        allow(mock_policy).to receive(:failure).with(target)
      end

      it 'returns nil' do
        result = webmentions.send_webmention(source, target)
        expect(result).to be_nil
      end

      it 'calls policy.failure' do
        webmentions.send_webmention(source, target)
        expect(mock_policy).to have_received(:failure).with(target)
      end
    end

    context 'when webmention endpoint is found' do
      before do
        allow(mock_client).to receive(:webmention_endpoint).with(target).and_return('https://example.com/webmention')
        allow(mock_client).to receive(:send_webmention).with(source, target).and_return(success_response)
      end

      context 'with successful response (200, 201, 202)' do
        before do
          allow(mock_policy).to receive(:success).with(target)
        end

        it 'calls policy.success' do
          webmentions.send_webmention(source, target)
          expect(mock_policy).to have_received(:success).with(target)
        end

        it 'returns the response body' do
          result = webmentions.send_webmention(source, target)
          expect(result).to eq('{"status": "success"}')
        end
      end

      context 'with error response' do
        before do
          allow(mock_client).to receive(:send_webmention).with(source, target).and_return(error_response)
          allow(mock_policy).to receive(:error).with(target)
        end

        it 'calls policy.error' do
          webmentions.send_webmention(source, target)
          expect(mock_policy).to have_received(:error).with(target)
        end

        it 'returns false' do
          result = webmentions.send_webmention(source, target)
          expect(result).to be false
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
    end
  end

  describe '#get_webmentions' do
    let(:targets) { ['https://example.com/page1', 'https://example.com/page2'] }
    let(:since_id) { 12345 }
    let(:api_response) do
      {
        'links' => [
          { 'id' => 1, 'source' => 'https://twitter.com/user/status/123', 'data' => { 'url' => 'https://example.com/mention1' } },
          { 'id' => 2, 'source' => 'https://mastodon.social/@user/456', 'data' => { 'url' => 'https://example.com/mention2' } }
        ]
      }
    end

    before do
      allow(webmentions).to receive(:get_webmention_io_response).and_return(api_response)
      allow(Jekyll::WebmentionIO).to receive(:log)
    end

    it 'constructs correct API parameters' do
      expected_params = 'target[]=https://example.com/page1&target[]=https://example.com/page2&since_id=12345&sort-by=published'
      expect(webmentions).to receive(:get_webmention_io_response).with(expected_params)
      webmentions.get_webmentions(targets, since_id)
    end

    it 'constructs API parameters without since_id when nil' do
      expected_params = 'target[]=https://example.com/page1&target[]=https://example.com/page2&sort-by=published'
      expect(webmentions).to receive(:get_webmention_io_response).with(expected_params)
      webmentions.get_webmentions(targets, nil)
    end

    it 'returns WebmentionItem instances' do
      result = webmentions.get_webmentions(targets, since_id)
      expect(result).to all(be_a(Jekyll::WebmentionIO::WebmentionItem))
      expect(result.length).to eq(2)
    end

    context 'when no webmentions are found' do
      let(:empty_response) { { 'links' => [] } }

      before do
        allow(webmentions).to receive(:get_webmention_io_response).and_return(empty_response)
      end

      it 'returns empty array' do
        result = webmentions.get_webmentions(targets, since_id)
        expect(result).to eq([])
      end
    end

    context 'when response has no links key' do
      let(:no_links_response) { {} }

      before do
        allow(webmentions).to receive(:get_webmention_io_response).and_return(no_links_response)
      end

      it 'returns empty array' do
        result = webmentions.get_webmentions(targets, since_id)
        expect(result).to eq([])
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

      it 'returns the response body' do
        result = webmentions.get_body_from_uri(uri)
        expect(result).to eq(response_body)
      end

      it 'does not call policy.failure' do
        webmentions.get_body_from_uri(uri)
        expect(mock_policy).not_to have_received(:failure)
      end
    end

    context 'when policy does not allow the URI' do
      before do
        allow(mock_policy).to receive(:uri_ok?).with(uri).and_return(false)
        allow(mock_client).to receive(:http_get)
      end

      it 'returns false' do
        result = webmentions.get_body_from_uri(uri)
        expect(result).to be false
      end

      it 'does not make HTTP request' do
        webmentions.get_body_from_uri(uri)
        expect(mock_client).not_to have_received(:http_get)
      end
    end

    context 'when HTTP request returns nil' do
      before do
        allow(mock_policy).to receive(:uri_ok?).with(uri).and_return(true)
        allow(mock_client).to receive(:http_get).with(uri, 10).and_return(nil)
        allow(mock_policy).to receive(:failure).with(uri)
      end

      it 'calls policy.failure' do
        webmentions.get_body_from_uri(uri)
        expect(mock_policy).to have_received(:failure).with(uri)
      end

      it 'returns false' do
        result = webmentions.get_body_from_uri(uri)
        expect(result).to be false
      end
    end
  end
end
