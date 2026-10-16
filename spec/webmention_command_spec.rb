# frozen_string_literal: true

require 'spec_helper'
require 'timecop'

describe Jekyll::WebmentionIO::Commands::WebmentionCommand do
  include_context 'webmention_io_stubs'
  include_context 'cache files'

  let(:policy) { Jekyll::WebmentionIO::WebmentionPolicy.new(config, caches) }
  let(:command) { described_class }

  # The queue and the bad-URI records as the caches hold them, unwrapped so an
  # expectation reads like the data the command works with.
  def outgoing_webmentions
    caches.outgoing_webmentions.to_h.transform_values(&:webmentions)
  end

  def bad_uris
    caches.bad_uris.to_h.transform_values(&:to_val)
  end

  # Queue a target for a source, as the generator would have.
  def queue_webmention(source, target)
    caches.outgoing_webmentions.store(source, { target => false })
  end

  context 'sends webmentions' do
    let(:source) { 'http://foo.bar.baz' }
    let(:target) { 'http://www.test.com' }
    let(:response) { { 'success' => true } }

    it 'sends basic webmention' do
      queue_webmention(source, target)
      allow(webmentions).to receive(:send_webmention).with(source, target).and_return(response.to_json)
      command.send_webmentions
      expect(outgoing_webmentions).to match({ source => { target => response } })
    end

    it 'skips webmentions that have a response' do
      caches.outgoing_webmentions.store(source, { target => {} })
      command.send_webmentions
      expect(outgoing_webmentions).to match({ source => { target => {} } })
    end

    it 'skips protocol-less links (1)' do
      caches.outgoing_webmentions.store(source, { 'www.test.com' => false })
      command.send_webmentions
      expect(outgoing_webmentions).to match({ source => { 'www.test.com' => false } })
    end

    it 'skips protocol-less links (2)' do
      caches.outgoing_webmentions.store(source, { '//www.test.com' => false })
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
      queue_webmention(source, target)
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
      queue_webmention(source, target)
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
      queue_webmention(source, target)
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
      queue_webmention(source, target)
      allow(client).to receive(:webmention_endpoint).with(target).and_raise(StandardError.new('No bueno'))
      config.parse({ 'bad_uri_policy' => { 'failure' => 'ignore' } })
      command.send_webmentions
      command.send_webmentions
      expect(outgoing_webmentions).to match({ source => { target => 2 } })
    end

    it 'handles ban on failure' do
      queue_webmention(source, target)
      allow(client).to receive(:webmention_endpoint).with(target).and_raise(StandardError.new('No bueno'))
      config.parse({ 'bad_uri_policy' => { 'failure' => 'ban' } })
      command.send_webmentions
      command.send_webmentions
      expect(outgoing_webmentions).to match({ source => { target => 1 } })
    end

    it 'handles target in blacklist' do
      queue_webmention(source, target)
      config.parse({ 'bad_uri_policy' => { 'blacklist' => [target] } })
      command.send_webmentions
      expect(outgoing_webmentions).to match({ source => { target => false } })
    end

    it 'handles target in whitelist' do
      queue_webmention(source, target)
      allow(client).to receive(:webmention_endpoint).with(target).and_raise(StandardError.new('No bueno'))
      config.parse({ 'bad_uri_policy' => { 'failure' => 'ban', 'whitelist' => [target] } })
      command.send_webmentions
      command.send_webmentions
      expect(outgoing_webmentions).to match({ source => { target => 2 } })
    end

    it 'handles retry while inside delay period' do
      queue_webmention(source, target)
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
      queue_webmention(source, target)
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
      queue_webmention(source, target)
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

    it 'gives up on a target that passes the configured maximum attempts' do
      give_up_target = 'http://giveup.test.com'
      exhausted_target = 'http://skipped.test.com'

      caches.outgoing_webmentions.store(source, { give_up_target => false, exhausted_target => false })
      # Already at the policy's retry limit, so uri_ok? skips it without reaching
      # the network, leaving the fresh target to exhaust the command's own limit.
      caches.bad_uris.store('skipped.test.com', { 'state' => 'failure', 'attempts' => 2, 'last_checked' => Time.now.to_s })

      allow(client).to receive(:webmention_endpoint).with(give_up_target).and_raise(StandardError.new('No bueno'))
      allow(Jekyll::WebmentionIO).to receive(:log).and_call_original

      config.parse({
                     'max_attempts' => 1,
                     'bad_uri_policy' => {
                       'failure' => {
                         'policy' => 'retry',
                         'max_attempts' => 2,
                         'retry_delay' => [0]
                       }
                     }
                   })

      command.send_webmentions
      command.send_webmentions

      expect(outgoing_webmentions).to match(
        source => { give_up_target => '', exhausted_target => false }
      )
      expect(Jekyll::WebmentionIO).to have_received(:log).with('msg', "Giving up sending from #{source} to #{give_up_target}.")
    end
  end
end
