require 'spec_helper'
require 'securerandom'
require 'timecop'

describe Jekyll::WebmentionIO::GatherWebmentions do
  before do
    Jekyll.logger.log_level = :error

    @config = SpecHelper::MockConfig.new
    @caches = SpecHelper::MockCaches.new
    @webmentions = SpecHelper::MockWebmentions.new

    # Just an arbitrary, non-leap-year (for simplicity) start date for various date-based tests
    @epoch = DateTime.new(2002, 1, 17)

    Jekyll::WebmentionIO.bootstrap(nil, @config, @caches, nil, @webmentions)

    @generator = Jekyll::WebmentionIO::GatherWebmentions.new
  end

  it 'gathers a single webmention' do
    page = SpecHelper::MockPage.new(url: 'foo.bar.baz')

    @config.documents.append(page)
    wm = @webmentions.add(uri: page.uri, source: 'http://yadda.yadda.yadda')

    @generator.generate

    expect(@webmentions.last_targets).to contain_exactly(page.uri)
    expect(@caches.incoming_webmentions).to match(page.url => { wm.id => wm.to_hash })
  end

  it 'handles a redirect' do
    page = SpecHelper::MockPage.new(url: 'foo.bar.baz', data: { 'redirect_from' => 'hello.world' })

    @config.documents.append(page)
    wm = @webmentions.add(uri: page.redirect, source: 'http://yadda.yadda.yadda')

    @generator.generate

    expect(@webmentions.last_targets).to contain_exactly(page.uri, page.redirect)
    expect(@caches.incoming_webmentions).to match(page.url => { wm.id => wm.to_hash })
  end

  it 'handles legacy domain' do
    @config.legacy_domains << 'http://legacy.domain'

    page = SpecHelper::MockPage.new(url: 'foo.bar.baz')
    legacy_uri = File.join('http://legacy.domain', page.url)

    @config.documents.append(page)
    wm = @webmentions.add(uri: legacy_uri, source: 'http://yadda.yadda.yadda')

    @generator.generate

    expect(@webmentions.last_targets).to contain_exactly(page.uri, legacy_uri)
    expect(@caches.incoming_webmentions).to match(page.url => { wm.id => wm.to_hash })
  end

  it 'requests new webmentions' do
    page = SpecHelper::MockPage.new(url: 'foo.bar.baz', data: { 'redirect_from' => 'hello.world' })

    @config.documents.append(page)
    wm = @webmentions.add(uri: page.redirect, source: 'http://yadda.yadda.yadda')

    @generator.generate

    expect(@webmentions.last_since_id).to eq(false)

    @webmentions.clear

    @generator.generate

    expect(@webmentions.last_since_id).to eq(wm.id)
  end

  it 'throttles posts from last week daily' do
    page = SpecHelper::MockPage.new(url: 'foo.bar.baz', date: @epoch - 7)

    @config.documents.append(page)
    @config.throttle_lookups = { 'last_week' => 'daily' }

    Timecop.freeze(@epoch) { @generator.generate }

    @webmentions.clear
    Timecop.freeze(@epoch) { @generator.generate }

    expect(@webmentions.last_targets).to be_empty

    @webmentions.clear
    Timecop.freeze(@epoch + 1) { @generator.generate }

    expect(@webmentions.last_targets.count).to eq(1)
  end

  it 'throttles posts from last month weekly' do
    page = SpecHelper::MockPage.new(url: 'foo.bar.baz', date: DateTime.new(2001, 12, 31))

    @config.documents.append(page)
    @config.throttle_lookups = { 'last_month' => 'weekly' }

    Timecop.freeze(@epoch) { @generator.generate }

    @webmentions.clear
    Timecop.freeze(@epoch + 6) { @generator.generate }

    expect(@webmentions.last_targets).to be_empty

    @webmentions.clear
    Timecop.freeze(@epoch + 7) { @generator.generate }

    expect(@webmentions.last_targets.count).to eq(1)
  end

  it 'throttles posts from last year every two weeks' do
    page = SpecHelper::MockPage.new(url: 'foo.bar.baz', date: DateTime.new(2001, 6, 1))

    @config.documents.append(page)
    @config.throttle_lookups = { 'last_year' => 'every 2 weeks' }

    Timecop.freeze(@epoch) { @generator.generate }

    @webmentions.clear
    Timecop.freeze(DateTime.new(2002, 1, 30)) { @generator.generate }

    expect(@webmentions.last_targets).to be_empty

    @webmentions.clear
    Timecop.freeze(DateTime.new(2002, 1, 31)) { @generator.generate }

    expect(@webmentions.last_targets.count).to eq(1)
  end

  it 'throttles old posts monthly' do
    page = SpecHelper::MockPage.new(url: 'foo.bar.baz', date: DateTime.new(2000, 6, 1))

    @config.documents.append(page)
    @config.throttle_lookups = { 'older' => 'monthly' }

    Timecop.freeze(@epoch) { @generator.generate }

    @webmentions.clear
    Timecop.freeze(DateTime.new(2002, 2, 16)) { @generator.generate }

    expect(@webmentions.last_targets).to be_empty

    @webmentions.clear
    Timecop.freeze(DateTime.new(2002, 2, 17)) { @generator.generate }

    expect(@webmentions.last_targets.count).to eq(1)
  end

  it 'honours pause_lookups setting' do
    page = SpecHelper::MockPage.new(url: 'foo.bar.baz')

    @config.documents.append(page)
    @config.pause_lookups = true

    @generator.generate

    expect(@webmentions.last_targets).to be_empty
  end
end
