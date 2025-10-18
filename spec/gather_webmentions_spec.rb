# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'
require 'timecop'

describe Jekyll::WebmentionIO::GatherWebmentions do
  let(:config) { double('Jekyll::WebmentionIO::Config') }
  let(:caches) { double('Jekyll::WebmentionIO::Caches') }
  let(:webmentions) { instance_double('Jekyll::WebmentionIO::Webmentions') }
  let(:site) { instance_double('Jekyll::Site') }
  let(:policy) { double('Jekyll::WebmentionIO::WebmentionPolicy') }
  let(:incoming_webmentions_cache) { spy('Cache') }
  let(:site_lookups_cache) { spy('Cache') }

  before do
    Jekyll.logger.log_level = :error

    allow(Jekyll::WebmentionIO).to receive(:config).and_return(config)
    allow(Jekyll::WebmentionIO).to receive(:caches).and_return(caches)
    allow(Jekyll::WebmentionIO).to receive(:webmentions).and_return(webmentions)
    allow(Jekyll::WebmentionIO).to receive(:site).and_return(site)
    allow(Jekyll::WebmentionIO).to receive(:policy).and_return(policy)

    allow(caches).to receive(:incoming_webmentions).and_return(incoming_webmentions_cache)
    allow(caches).to receive(:site_lookups).and_return(site_lookups_cache)

    allow(config).to receive(:pause_lookups).and_return(false)
    allow(config).to receive(:legacy_domains).and_return([])
    allow(config).to receive(:throttle_lookups).and_return({})
    allow(config).to receive(:site_url).and_return('https://example.com')

    allow(webmentions).to receive(:get_webmentions).and_return([])
    allow(webmentions).to receive(:get_body_from_uri).and_return('')

    allow(policy).to receive(:post_should_be_throttled?).and_return(false)
  end

  let(:generator) { described_class.new }

  context 'when gathering webmentions' do
    let(:page) { double('Jekyll::Page', url: '/page.html', data: {}, uri: 'https://example.com/page.html') }
    let(:webmention) do
      item = Jekyll::WebmentionIO::WebmentionItem.new({ 'id' => '12345', 'source' => 'http://source.com', 'target' => page.uri, 'data' => {} })
      allow(item).to receive(:to_hash).and_return({ 'id' => '12345' })
      item
    end

    before do
      allow(config).to receive(:documents).and_return([page])
      allow(webmentions).to receive(:get_webmentions).and_return([webmention])
      allow(incoming_webmentions_cache).to receive(:dig).and_return(nil)
      allow(site_lookups_cache).to receive(:[]).and_return(nil)
    end

    it 'gathers a single webmention' do
      generator.generate(site)
      expect(webmentions).to have_received(:get_webmentions).with([page.uri], anything)
      expect(incoming_webmentions_cache).to have_received(:[]=).with(page.url, anything)
    end

    it 'handles a redirect' do
      allow(page).to receive(:data).and_return({ 'redirect_from' => '/redirect.html' })
      redirect_uri = 'https://example.com/redirect.html'
      generator.generate(site)
      expect(webmentions).to have_received(:get_webmentions).with([page.uri, redirect_uri], anything)
    end

    it 'handles legacy domain' do
      allow(config).to receive(:legacy_domains).and_return(['http://legacy.com'])
      legacy_uri = 'http://legacy.com/page.html'
      generator.generate(site)
      expect(webmentions).to have_received(:get_webmentions).with([page.uri, legacy_uri], anything)
    end

    it 'requests new webmentions' do
      allow(incoming_webmentions_cache).to receive(:dig).with(page.url, anything).and_return({ 'raw' => { 'id' => '54321', 'verified_date' => '2025-10-18' } })
      generator.generate(site)
      expect(webmentions).to have_received(:get_webmentions).with([page.uri], '54321')
    end
  end

  context 'when throttling lookups' do
    let(:page) { double('Jekyll::Page', url: '/page.html', data: {}, uri: 'https://example.com/page.html', date: DateTime.now) }

    before do
      allow(config).to receive(:documents).and_return([page])
      allow(incoming_webmentions_cache).to receive(:dig).and_return(nil)
    end

    it 'throttles posts from last week daily' do
      allow(config).to receive(:throttle_lookups).and_return({ 'last_week' => 'daily' })
      allow(page).to receive(:date).and_return(DateTime.now - 7)

      # Initial state
      allow(site_lookups_cache).to receive(:[]).with(page.url).and_return(nil)
      allow(policy).to receive(:post_should_be_throttled?).and_return(false)

      # First run, should not be throttled
      generator.generate(site)
      expect(webmentions).to have_received(:get_webmentions).once

      # Second run, should be throttled
      allow(site_lookups_cache).to receive(:[]).with(page.url).and_return(Date.today)
      allow(policy).to receive(:post_should_be_throttled?).and_return(true)
      generator.generate(site)
      expect(webmentions).to have_received(:get_webmentions).once # still once

      # Third run, next day, should not be throttled
      Timecop.travel(Date.today + 1) do
        allow(site_lookups_cache).to receive(:[]).with(page.url).and_return(Date.today)
        allow(policy).to receive(:post_should_be_throttled?).and_return(false)
        generator.generate(site)
        expect(webmentions).to have_received(:get_webmentions).twice
      end
    end

    it 'throttles posts from last month weekly' do
      allow(config).to receive(:throttle_lookups).and_return({ 'last_month' => 'weekly' })
      allow(page).to receive(:date).and_return(DateTime.now - 30)

      # Initial state
      allow(site_lookups_cache).to receive(:[]).with(page.url).and_return(nil)
      allow(policy).to receive(:post_should_be_throttled?).and_return(false)

      # First run, should not be throttled
      generator.generate(site)
      expect(webmentions).to have_received(:get_webmentions).once

      # Second run, should be throttled
      allow(site_lookups_cache).to receive(:[]).with(page.url).and_return(Date.today)
      allow(policy).to receive(:post_should_be_throttled?).and_return(true)
      generator.generate(site)
      expect(webmentions).to have_received(:get_webmentions).once # still once

      # Third run, next week, should not be throttled
      Timecop.travel(Date.today + 7) do
        allow(site_lookups_cache).to receive(:[]).with(page.url).and_return(Date.today)
        allow(policy).to receive(:post_should_be_throttled?).and_return(false)
        generator.generate(site)
        expect(webmentions).to have_received(:get_webmentions).twice
      end
    end

    it 'throttles posts from last year every two weeks' do
      allow(config).to receive(:throttle_lookups).and_return({ 'last_year' => 'every 2 weeks' })
      allow(page).to receive(:date).and_return(DateTime.now - 365)

      # Initial state
      allow(site_lookups_cache).to receive(:[]).with(page.url).and_return(nil)
      allow(policy).to receive(:post_should_be_throttled?).and_return(false)

      # First run, should not be throttled
      generator.generate(site)
      expect(webmentions).to have_received(:get_webmentions).once

      # Second run, should be throttled
      allow(site_lookups_cache).to receive(:[]).with(page.url).and_return(Date.today)
      allow(policy).to receive(:post_should_be_throttled?).and_return(true)
      generator.generate(site)
      expect(webmentions).to have_received(:get_webmentions).once # still once

      # Third run, 2 weeks later, should not be throttled
      Timecop.travel(Date.today + 14) do
        allow(site_lookups_cache).to receive(:[]).with(page.url).and_return(Date.today)
        allow(policy).to receive(:post_should_be_throttled?).and_return(false)
        generator.generate(site)
        expect(webmentions).to have_received(:get_webmentions).twice
      end
    end

    it 'throttles old posts monthly' do
      allow(config).to receive(:throttle_lookups).and_return({ 'older' => 'monthly' })
      allow(page).to receive(:date).and_return(DateTime.now - 400)

      # Initial state
      allow(site_lookups_cache).to receive(:[]).with(page.url).and_return(nil)
      allow(policy).to receive(:post_should_be_throttled?).and_return(false)

      # First run, should not be throttled
      generator.generate(site)
      expect(webmentions).to have_received(:get_webmentions).once

      # Second run, should be throttled
      allow(site_lookups_cache).to receive(:[]).with(page.url).and_return(Date.today)
      allow(policy).to receive(:post_should_be_throttled?).and_return(true)
      generator.generate(site)
      expect(webmentions).to have_received(:get_webmentions).once # still once

      # Third run, next month, should not be throttled
      Timecop.travel(Date.today + 30) do
        allow(site_lookups_cache).to receive(:[]).with(page.url).and_return(Date.today)
        allow(policy).to receive(:post_should_be_throttled?).and_return(false)
        generator.generate(site)
        expect(webmentions).to have_received(:get_webmentions).twice
      end
    end
  end

  it 'honours pause_lookups setting' do
    allow(config).to receive(:pause_lookups).and_return(true)
    generator.generate(site)
    expect(webmentions).not_to have_received(:get_webmentions)
  end
end
