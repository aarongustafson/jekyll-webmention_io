# frozen_string_literal: true

require 'spec_helper'
require 'timecop'

describe Jekyll::WebmentionIO::Commands::WebmentionCommand do
  include_context 'webmention_io_stubs'

  let(:policy) { Jekyll::WebmentionIO::WebmentionPolicy.new(config, caches) }

  let(:outgoing_webmentions) { {} }
  let(:bad_uris) { {} }
  let(:command) { described_class }

  before do
    allow(caches).to receive(:outgoing_webmentions).and_return(outgoing_webmentions)
    allow(caches).to receive(:bad_uris).and_return(bad_uris)
    allow(outgoing_webmentions).to receive(:write)
    allow(bad_uris).to receive(:write)
  end

  context 'sends webmentions' do
    let(:source) { 'http://foo.bar.baz' }
    let(:target) { 'http://www.test.com' }
    let(:response) { { 'success' => true } }

    it 'sends basic webmention' do
      outgoing_webmentions[source] = { target => false }
      allow(webmentions).to receive(:send_webmention).with(source, target).and_return(response.to_json)
      command.send_webmentions
      expect(outgoing_webmentions).to match({ source => { target => response } })
    end

    it 'skips webmentions that have a response' do
      outgoing_webmentions[source] = { target => {} }
      command.send_webmentions
      expect(outgoing_webmentions).to match({ source => { target => {} } })
    end

    it 'skips protocol-less links (1)' do
      outgoing_webmentions[source] = { 'www.test.com' => false }
      command.send_webmentions
      expect(outgoing_webmentions).to match({ source => { 'www.test.com' => false } })
    end

    it 'skips protocol-less links (2)' do
      outgoing_webmentions[source] = { '//www.test.com' => false }
      command.send_webmentions
      expect(outgoing_webmentions).to match({ source => { '//www.test.com' => false } })
    end
  end

  context 'handles webmention sending failures' do
    let(:source) { 'http://foo.bar.baz' }
    let(:target) { 'http://www.test.com' }
    let(:client) { instance_double(Jekyll::WebmentionIO::NetworkClient) }
    let(:webmentions) { Jekyll::WebmentionIO::Webmentions.new(policy, client) }

    before do
      allow(Jekyll::WebmentionIO).to receive(:webmentions).and_return(webmentions)
    end

    it 'handles failure getting endpoint' do
      outgoing_webmentions[source] = { target => false }
      allow(client).to receive(:webmention_endpoint).with(target).and_raise(StandardError.new('No bueno'))
      command.send_webmentions
      expect(outgoing_webmentions).to match({ source => { target => 1 } })
      expect(bad_uris).to match(
        hash_including(
          'www.test.com' => hash_including('state' => 'failure', 'attempts' => 1)
        )
      )
    end

    it 'handles webmentions unsupported' do
      outgoing_webmentions[source] = { target => false }
      allow(client).to receive(:webmention_endpoint).with(target).and_return(nil)
      command.send_webmentions
      expect(outgoing_webmentions).to match({ source => { target => 1 } })
      expect(bad_uris).to match(
        hash_including(
          'www.test.com' => hash_including('state' => 'unsupported', 'attempts' => 1)
        )
      )
    end

    it 'handles webmention failure' do
      outgoing_webmentions[source] = { target => false }
      allow(client).to receive(:webmention_endpoint).with(target).and_return(target)
      allow(client).to receive(:send_webmention).with(source, target).and_return(Struct.new(:code, :body).new(404))
      command.send_webmentions
      expect(outgoing_webmentions).to match({ source => { target => 1 } })
      expect(bad_uris).to match(
        hash_including(
          'www.test.com' => hash_including('state' => 'error', 'attempts' => 1)
        )
      )
    end

    it 'handles ignore on failure' do
      outgoing_webmentions[source] = { target => false }
      allow(client).to receive(:webmention_endpoint).with(target).and_raise(StandardError.new('No bueno'))
      config.parse({ 'bad_uri_policy' => { 'failure' => 'ignore' } })
      command.send_webmentions
      command.send_webmentions
      expect(outgoing_webmentions).to match({ source => { target => 2 } })
    end

    it 'handles ban on failure' do
      outgoing_webmentions[source] = { target => false }
      allow(client).to receive(:webmention_endpoint).with(target).and_raise(StandardError.new('No bueno'))
      config.parse({ 'bad_uri_policy' => { 'failure' => 'ban' } })
      command.send_webmentions
      command.send_webmentions
      expect(outgoing_webmentions).to match({ source => { target => 1 } })
    end

    it 'handles target in blacklist' do
      outgoing_webmentions[source] = { target => false }
      config.parse({ 'bad_uri_policy' => { 'blacklist' => [target] } })
      command.send_webmentions
      expect(outgoing_webmentions).to match({ source => { target => false } })
    end

    it 'handles target in whitelist' do
      outgoing_webmentions[source] = { target => false }
      allow(client).to receive(:webmention_endpoint).with(target).and_raise(StandardError.new('No bueno'))
      config.parse({ 'bad_uri_policy' => { 'failure' => 'ban', 'whitelist' => [target] } })
      command.send_webmentions
      command.send_webmentions
      expect(outgoing_webmentions).to match({ source => { target => 2 } })
    end

    it 'handles retry while inside delay period' do
      outgoing_webmentions[source] = { target => false }
      allow(client).to receive(:webmention_endpoint).with(target).and_raise(StandardError.new('No bueno'))
      config.parse({ 
        'bad_uri_policy' => { 
          'failure' => { 
            'policy' => 'retry', 
            'max_attempts' => 2, 
            'retry_delay' => [1] 
          } 
        } 
      })
      command.send_webmentions
      command.send_webmentions
      expect(outgoing_webmentions).to match({ source => { target => 1 } })
    end

    it 'handles retry outside delay period' do
      outgoing_webmentions[source] = { target => false }
      allow(client).to receive(:webmention_endpoint).with(target).and_raise(StandardError.new('No bueno'))
      config.parse({ 
        'bad_uri_policy' => { 
          'failure' => { 
            'policy' => 'retry', 
            'max_attempts' => 2, 
            'retry_delay' => [1] 
          } 
        } 
      })
      command.send_webmentions
      Timecop.freeze(DateTime.now + (1.0 / 24.0)) { command.send_webmentions }
      expect(outgoing_webmentions).to match({ source => { target => 2 } })
    end

    it 'handles retry with multiple delay periods' do
      outgoing_webmentions[source] = { target => false }
      allow(client).to receive(:webmention_endpoint).with(target).and_raise(StandardError.new('No bueno'))
      config.parse({ 
        'bad_uri_policy' => { 
          'failure' => { 
            'policy' => 'retry', 
            'max_attempts' => 5, 
            'retry_delay' => [1, 2] 
          } 
        } 
      })

      command.send_webmentions
      Timecop.freeze(DateTime.now + (1.0 / 24.0)) { command.send_webmentions }
      Timecop.freeze(DateTime.now + (2.0 / 24.0)) { command.send_webmentions }
      Timecop.freeze(DateTime.now + (3.0 / 24.0)) { command.send_webmentions }
      Timecop.freeze(DateTime.now + (4.0 / 24.0)) { command.send_webmentions }
      Timecop.freeze(DateTime.now + (5.0 / 24.0)) { command.send_webmentions }
      Timecop.freeze(DateTime.now + (6.0 / 24.0)) { command.send_webmentions }

      expect(outgoing_webmentions).to match({ source => { target => 4 } })
    end
  end
end
