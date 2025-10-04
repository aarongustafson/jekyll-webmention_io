require 'spec_helper'
require 'timecop'

describe Jekyll::WebmentionIO::Commands::WebmentionCommand do
  NetworkClient = Jekyll::WebmentionIO::NetworkClient

  before do
    Jekyll.logger.log_level = :error

    @config = SpecHelper::MockConfig.new
    @caches = SpecHelper::MockCaches.new
    @command = Jekyll::WebmentionIO::Commands::WebmentionCommand
  end

  context 'with mock webmentions class' do
    before do
      @webmentions = SpecHelper::MockWebmentions.new

      Jekyll::WebmentionIO.bootstrap(nil, @config, @caches, nil, @webmentions)
    end

    # This method adds an outgoing webmention to the cache and sets up a
    # response object in our mock.
    def set_up_webmention(source, target, body = false)
      response = { 'success' => true }

      @caches.outgoing_webmentions[source] = { target => body }
      @webmentions.response(source, target, response)

      response
    end

    it 'sends basic webmention' do
      source = 'http://foo.bar.baz'
      target = 'http://www.test.com'

      response = set_up_webmention(source, target)

      @command.send_webmentions

      expect(@caches.outgoing_webmentions).to match({ source => { target => response } })
    end

    it 'skips webmentions that have a response' do
      source = 'http://foo.bar.baz'
      target = 'http://www.test.com'

      set_up_webmention(source, target, {})

      @command.send_webmentions

      expect(@caches.outgoing_webmentions).to match({ source => { target => {} } })
    end

    it 'skips protocol-less links (1)' do
      source = 'http://foo.bar.baz'
      target = 'www.test.com'

      set_up_webmention(source, target)

      @command.send_webmentions

      expect(@caches.outgoing_webmentions).to match({ source => { target => false } })
    end

    it 'skips protocol-less links (2)' do
      source = 'http://foo.bar.baz'
      target = '//www.test.com'

      set_up_webmention(source, target)

      @command.send_webmentions

      expect(@caches.outgoing_webmentions).to match({ source => { target => false } })
    end
  end

  context 'with mock network client' do
    before do
      @client = SpecHelper::MockNetworkClient.new
      policy = Jekyll::WebmentionIO::WebmentionPolicy.new(@config, @caches)
      @webmentions = Jekyll::WebmentionIO::Webmentions.new(policy, @client)

      Jekyll::WebmentionIO.bootstrap(nil, @config, @caches, policy, @webmentions)
    end

    it 'handles failure getting endpoint' do
      source = 'http://foo.bar.baz'
      target = 'http://www.test.com'

      @caches.outgoing_webmentions[source] = { target => false }
      @client.endpoint_responses[target] = StandardError.new('No bueno')

      @command.send_webmentions

      expect(@caches.outgoing_webmentions).to match({ source => { target => 1 } })
      expect(@caches.bad_uris).to match(hash_including(
        'www.test.com' => hash_including('state' => 'failure', 'attempts' => 1)
      ))
    end

    it 'handles webmentions unsupported' do
      source = 'http://foo.bar.baz'
      target = 'http://www.test.com'

      @caches.outgoing_webmentions[source] = { target => false }
      @client.endpoint_responses[target] = {}

      @command.send_webmentions

      expect(@caches.outgoing_webmentions).to match({ source => { target => 1 } })
      expect(@caches.bad_uris).to match(hash_including(
        'www.test.com' => hash_including('state' => 'unsupported', 'attempts' => 1)
      ))
    end

    it 'handles webmention failure' do
      source = 'http://foo.bar.baz'
      target = 'http://www.test.com'

      @caches.outgoing_webmentions[source] = { target => false }
      @client.endpoint_responses[target] = target
      @client.webmention_responses[target] = { source => Struct.new(:code, :body).new(404) }

      @command.send_webmentions

      expect(@caches.outgoing_webmentions).to match({ source => { target => 1 } })
      expect(@caches.bad_uris).to match(hash_including(
        'www.test.com' => hash_including('state' => 'error', 'attempts' => 1)
      ))
    end

    it 'handles ignore on failure' do
      source = 'http://foo.bar.baz'
      target = 'http://www.test.com'

      @caches.outgoing_webmentions[source] = { target => false }
      @client.endpoint_responses[target] = StandardError.new('No bueno')
      @config.bad_uri_policy.set_policy('failure', 'ignore')

      @command.send_webmentions
      @command.send_webmentions

      expect(@caches.outgoing_webmentions).to match({ source => { target => 2 } })
    end

    it 'handles ban on failure' do
      source = 'http://foo.bar.baz'
      target = 'http://www.test.com'

      @caches.outgoing_webmentions[source] = { target => false }
      @client.endpoint_responses[target] = StandardError.new('No bueno')
      @config.bad_uri_policy.set_policy('failure', 'ban')

      @command.send_webmentions
      @command.send_webmentions

      expect(@caches.outgoing_webmentions).to match({ source => { target => 1 } })
    end

    it 'handles target in blacklist' do
      source = 'http://foo.bar.baz'
      target = 'http://www.test.com'

      @caches.outgoing_webmentions[source] = { target => false }
      @client.endpoint_responses[target] = { webmention: target }
      @client.webmention_responses[target] = { source => Struct.new(:code, :body).new(200, "{}") }
      @config.bad_uri_policy.blacklist << target

      @command.send_webmentions

      expect(@caches.outgoing_webmentions).to match({ source => { target => false } })
    end

    it 'handles target in whitelist' do
      source = 'http://foo.bar.baz'
      target = 'http://www.test.com'

      @caches.outgoing_webmentions[source] = { target => false }
      @client.endpoint_responses[target] = StandardError.new('No bueno')
      @config.bad_uri_policy.set_policy('failure', 'ban')
      @config.bad_uri_policy.whitelist << target

      @command.send_webmentions
      @command.send_webmentions

      expect(@caches.outgoing_webmentions).to match({ source => { target => 2 } })
    end

    it 'handles retry while inside delay period' do
      source = 'http://foo.bar.baz'
      target = 'http://www.test.com'

      @caches.outgoing_webmentions[source] = { target => false }
      @client.endpoint_responses[target] = StandardError.new('No bueno')

      # Set a 1 hour retry period, and retry immediately
      @config.bad_uri_policy.set_policy('failure', 'retry', 2, [1])

      @command.send_webmentions
      @command.send_webmentions

      expect(@caches.outgoing_webmentions).to match({ source => { target => 1 } })
    end

    it 'handles retry outside delay period' do
      source = 'http://foo.bar.baz'
      target = 'http://www.test.com'

      @caches.outgoing_webmentions[source] = { target => false }
      @client.endpoint_responses[target] = StandardError.new('No bueno')

      # Set a 1 hour retry period, and retry immediately
      @config.bad_uri_policy.set_policy('failure', 'retry', 2, [1])

      @command.send_webmentions

      Timecop.freeze(DateTime.now + 1/24r) { @command.send_webmentions }

      expect(@caches.outgoing_webmentions).to match({ source => { target => 2 } })
    end

    it 'handles retry with multiple delay periods' do
      source = 'http://foo.bar.baz'
      target = 'http://www.test.com'

      @caches.outgoing_webmentions[source] = { target => false }
      @client.endpoint_responses[target] = StandardError.new('No bueno')

      # Set a 1 hour retry period, and retry immediately
      @config.bad_uri_policy.set_policy('failure', 'retry', 5, [1, 2])

      @command.send_webmentions

      Timecop.freeze(DateTime.now + 1/24r) { @command.send_webmentions }
      Timecop.freeze(DateTime.now + 2/24r) { @command.send_webmentions }

      Timecop.freeze(DateTime.now + 3/24r) { @command.send_webmentions }
      Timecop.freeze(DateTime.now + 4/24r) { @command.send_webmentions }

      Timecop.freeze(DateTime.now + 5/24r) { @command.send_webmentions }
      Timecop.freeze(DateTime.now + 6/24r) { @command.send_webmentions }

      expect(@caches.outgoing_webmentions).to match({ source => { target => 4 } })
    end
  end
end
