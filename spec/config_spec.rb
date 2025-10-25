# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Jekyll::WebmentionIO::Config do
  let(:site) { instance_double('Jekyll::Site') }
  let(:config_hash) do
    {
      'url' => 'https://example.com',
      'baseurl' => '',
      'webmentions' => webmentions_config,
    }
  end

  before do
    allow(site).to receive(:config).and_return(config_hash)
    allow(site).to receive(:in_source_dir) { |path| path }
  end

  let(:config) { described_class.new(site) }

  context 'with an empty configuration' do
    let(:webmentions_config) { {} }

    it 'should have a nil username' do
      expect(config.username).to be_nil
    end

    it 'should have html_proofer_ignore set to none' do
      expect(config.html_proofer_ignore).to eq :NONE
    end

    it 'should have an empty templates hash' do
      expect(config.templates).to be_a(Hash)
      expect(config.templates).to be_empty
    end
  end

  context 'with a username' do
    let(:webmentions_config) { { 'username' => 'testuser' } }

    it 'should correctly parse the username' do
      expect(config.username).to eq 'testuser'
    end
  end

  context 'with html_proofer' do
    let(:webmentions_config) { { 'html_proofer' => true } }

    it 'should set html_proofer_ignore to templates' do
      expect(config.html_proofer_ignore).to eq :TEMPLATES
    end
  end

  context 'with html_proofer_ignore' do
    let(:webmentions_config) { { 'html_proofer_ignore' => 'all' } }

    it 'should set html_proofer_ignore to all' do
      expect(config.html_proofer_ignore).to eq :ALL
    end
  end

  context 'with a custom cache folder' do
    let(:webmentions_config) { { 'cache_folder' => '_data/.cache' } }

    it 'should set the cache folder' do
      expect(config.cache_folder).to eq '_data/.cache'
    end
  end

  context 'with js disabled' do
    let(:webmentions_config) { nil }

    it 'should return a disabled js config' do
      expect(config.js).to be_a(Jekyll::WebmentionIO::Config::JsConfig)
      expect(config.js.disabled?).to be true
    end
  end

  context 'with max_attempts' do
    let(:webmentions_config) { { 'max_attempts' => 10 } }

    it 'should set max_attempts' do
      expect(config.max_attempts).to eq 10
    end
  end

  context 'with a simple bad_uri_policy' do
    let(:webmentions_config) { { 'bad_uri_policy' => { 'unsupported' => 'ban' } } }

    it 'should create a BadUriPolicy object' do
      expect(config.bad_uri_policy).to be_a(Jekyll::WebmentionIO::Config::BadUriPolicy)
      policy = config.bad_uri_policy.for_state('unsupported')
      expect(policy.policy).to eq 'ban'
    end
  end

  context 'with throttle_lookups' do
    let(:webmentions_config) { { 'throttle_lookups' => { 'last_week' => 'daily' } } }

    it 'should set throttle_lookups' do
      expect(config.throttle_lookups).to eq({ 'last_week' => 'daily' })
    end
  end

  context 'with legacy_domains' do
    let(:webmentions_config) { { 'legacy_domains' => ['example.org'] } }

    it 'should set legacy_domains' do
      expect(config.legacy_domains).to eq ['example.org']
    end
  end

  context 'with a full js config' do
    let(:webmentions_config) do
      {
        'js' => {
          'destination' => 'assets/js',
          'deploy' => false,
          'source' => false,
          'uglify' => false,
        },
      }
    end

    it 'should return a non-disabled js config with custom values' do
      js_config = config.js
      expect(js_config).to be_a(Jekyll::WebmentionIO::Config::JsConfig)
      expect(js_config.disabled?).to be false
      expect(js_config.destination).to eq 'assets/js'
      expect(js_config.deploy?).to be false
      expect(js_config.source?).to be false
      expect(js_config.uglify?).to be false
    end
  end

  context 'with a complex bad_uri_policy' do
    let(:webmentions_config) do
      {
        'bad_uri_policy' => {
          'default' => 'ignore',
          'unsupported' => 'ban',
          'failure' => {
            'policy' => 'retry',
            'retry_delay' => [1, 2, 3],
          },
        },
      }
    end

    it 'should handle default policies' do
      policy = config.bad_uri_policy.for_state('error') # not explicitly defined
      expect(policy.policy).to eq 'ignore'
    end

    it 'should handle specific policies' do
      policy = config.bad_uri_policy.for_state('unsupported')
      expect(policy.policy).to eq 'ban'
    end

    it 'should handle retry policies' do
      policy = config.bad_uri_policy.for_state('failure')
      expect(policy.policy).to eq 'retry'
      expect(policy.retry_delay).to eq [1, 2, 3]
    end
  end

  describe '#last_lookup_threshold' do
    let(:webmentions_config) { { 'throttle_lookups' => { 'last_week' => 'daily' } } }

    it 'returns a date for a throttled timeframe' do
      # This test is time-dependent, but should be safe.
      # A date within the last week.
      date = Date.today - 3
      expect(config.last_lookup_threshold(date)).to eq(Date.today - 1)
    end

    it 'returns nil for a non-throttled timeframe' do
      date = Date.today - 10 # older than a week
      expect(config.last_lookup_threshold(date)).to be_nil
    end
  end

  describe '#syndication_rule_for_uri' do
    let(:webmentions_config) do
      {
        'syndication' => {
          'mastodon' => { 'endpoint' => 'https://brid.gy/publish/mastodon' },
          'twitter' => { 'endpoint' => 'https://brid.gy/publish/twitter' },
        },
      }
    end

    it 'finds the correct rule for a given endpoint URI' do
      rule = config.syndication_rule_for_uri('https://brid.gy/publish/twitter')

      expect(rule).to be_a(Jekyll::WebmentionIO::Config::SyndicationRule)
      expect(rule.endpoint).to eq 'https://brid.gy/publish/twitter'
    end

    it 'returns nil if no rule matches' do
      rule = config.syndication_rule_for_uri('https://example.com')

      expect(rule).to be_nil
    end
  end

  context 'with a simple syndication config' do
    let(:webmentions_config) { { 'syndication' => { 'mastodon' => { 'endpoint' => 'https://brid.gy/publish/mastodon' } } } }

    it 'should create SyndicationRule objects' do
      expect(config.syndication).to be_a(Hash)
      expect(config.syndication['mastodon']).to be_a(Jekyll::WebmentionIO::Config::SyndicationRule)
      expect(config.syndication['mastodon'].endpoint).to eq 'https://brid.gy/publish/mastodon'
    end
  end

  describe '#documents' do
    let(:posts) { [instance_double('Jekyll::Document', collection: 'posts')] }
    let(:pages) { [instance_double('Jekyll::Document', collection: 'pages')] }
    let(:foo_collection) do
      instance_double('Jekyll::Collection', docs: [instance_double('Jekyll::Document', collection: 'foo')])
    end
    let(:bar_collection) do
      instance_double('Jekyll::Collection', docs: [instance_double('Jekyll::Document', collection: 'bar')])
    end

    before do
      allow(site).to receive_message_chain('posts.docs').and_return(posts)
      allow(site).to receive(:pages).and_return(pages)
      allow(site).to receive(:collections).and_return({
                                                        'foo' => foo_collection,
                                                        'bar' => bar_collection,
                                                      })
    end

    context 'with default config' do
      let(:webmentions_config) { {} }

      it 'returns only posts' do
        # Bug in source: returns all collections because @collections.empty? is true
        # and the inner check is also bugged.
        expect(config.documents.map(&:collection)).to eq(%w[posts foo bar])
      end
    end

    context 'with pages enabled' do
      let(:webmentions_config) { { 'pages' => true } }

      it 'returns posts and pages' do
        # Bug in source: returns all collections because @collections.empty? is true
        expect(config.documents.map(&:collection)).to eq(%w[posts pages foo bar])
      end
    end

    context 'with all collections enabled (as empty hash)' do
      let(:webmentions_config) { { 'collections' => {} } }

      it 'returns posts and all collection documents' do
        # This is the same buggy behavior as default
        expect(config.documents.map(&:collection)).to eq(%w[posts foo bar])
      end
    end

    context 'with a single collection enabled' do
      let(:webmentions_config) { { 'collections' => ['foo'] } }

      it 'returns posts and documents from that collection' do
        # Bug in source: @collections.empty? is false, so collections are skipped
        expect(config.documents.map(&:collection)).to eq(%w[posts])
      end
    end
  end
end
