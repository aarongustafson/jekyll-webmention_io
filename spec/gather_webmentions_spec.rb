# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'
require 'timecop'

describe Jekyll::WebmentionIO::GatherWebmentions do
  include_context 'webmention_io_stubs'
  include_context 'cache files'
  include_context 'webmention lookup results'

  let(:documents) { [] }

  let(:generator) { described_class.new }

  before do
    allow(config).to receive(:documents).and_return(documents)
    allow(config).to receive(:site_url).and_return('https://example.com')

    allow(webmentions).to receive(:get_webmentions).and_return(lookup_result([]))
  end

  # The mentions the cache holds for a post.
  def cached_mentions(post)
    caches.incoming_webmentions[post.url]&.webmentions
  end

  # A post with a publication date, which is what decides whether it is new enough to
  # still be likely to receive its first mention.
  def dated_page(path, date)
    double('Jekyll::Page', url: path, data: {}, uri: "https://example.com#{path}", date: date)
  end

  context 'when gathering webmentions' do
    let(:page) { double('Jekyll::Page', url: '/page.html', data: {}, uri: 'https://example.com/page.html') }
    let(:other_page) { double('Jekyll::Page', url: '/other.html', data: {}, uri: 'https://example.com/other.html') }
    let(:webmention) { webmention_for('12345', page.uri) }

    before do
      documents << page
      allow(webmentions).to receive(:get_webmentions).and_return(lookup_result([webmention]))
    end

    it 'gathers a single webmention' do
      generator.generate(site)

      expect(webmentions).to have_received(:get_webmentions).with([page.uri], nil, 0)
      expect(cached_mentions(page)).to have_key('12345')
    end

    it 'keeps the mention it already holds when the service returns the same id again' do
      caches.incoming_webmentions.store(
        page.url,
        { '12345' => { 'raw' => { 'id' => 12_345, 'target' => page.uri, 'verified_date' => '2025-10-18' } } }
      )
      # webmention_for stamps a different verified_date, so an overwrite would show.
      again = webmention_for('12345', page.uri)
      allow(webmentions).to receive(:get_webmentions).and_return(lookup_result([again]))

      generator.generate(site)

      expect(cached_mentions(page).keys).to eq(['12345'])
      expect(cached_mentions(page)['12345']['raw']['verified_date']).to eq('2025-10-18')
    end

    it 'handles a redirect' do
      allow(page).to receive(:data).and_return({ 'redirect_from' => '/redirect.html' })
      redirect_uri = 'https://example.com/redirect.html'

      generator.generate(site)

      expect(webmentions).to have_received(:get_webmentions).with([page.uri, redirect_uri], nil, 0)
    end

    it 'files a mention sent to a redirected URL against the post' do
      allow(page).to receive(:data).and_return({ 'redirect_from' => '/redirect.html' })
      redirected = webmention_for('77', 'https://example.com/redirect.html')
      allow(webmentions).to receive(:get_webmentions).and_return(lookup_result([redirected]))

      generator.generate(site)

      expect(cached_mentions(page)).to have_key('77')
    end

    it 'handles legacy domain' do
      config.parse({ 'legacy_domains' => ['http://legacy.com'] })
      legacy_uri = 'http://legacy.com/page.html'

      generator.generate(site)

      expect(webmentions).to have_received(:get_webmentions).with([page.uri, legacy_uri], nil, 0)
    end

    it 'asks from the highest cached wm-id, not the last one stored' do
      caches.incoming_webmentions.store(
        page.url,
        {
          '100' => { 'raw' => { 'id' => 100, 'verified_date' => '2025-10-18' } },
          '9001' => { 'raw' => { 'id' => 9001, 'verified_date' => '2025-10-19' } },
          '300' => { 'raw' => { 'id' => 300, 'verified_date' => '2025-10-17' } }
        }
      )

      generator.generate(site)

      expect(webmentions).to have_received(:get_webmentions).with([page.uri], 9001, 0)
    end

    it 'recognises a post by a URL the service has already reported for it' do
      caches.incoming_webmentions.store(
        page.url,
        { '100' => { 'raw' => { 'id' => 100, 'target' => 'https://example.com/page/', 'verified_date' => '2025-10-18' } } }
      )
      refiled = webmention_for('101', 'https://example.com/page/')
      allow(webmentions).to receive(:get_webmentions).and_return(lookup_result([refiled]))

      generator.generate(site)

      expect(webmentions).to have_received(:get_webmentions).once
      expect(cached_mentions(page)).to have_key('101')
    end

    it 'learns where a page was filed, so the next build needs no fallback' do
      refiled = webmention_for('9', 'https://example.com/page/')
      allow(webmentions).to receive(:get_webmentions).and_return(lookup_result([refiled]))

      # Nothing is cached, so the answer names a page that matches nothing and the
      # request is redone for the post on its own -- which caches the mention, and
      # with it the URL the service filed the page under.
      generator.generate(site)

      requests = []
      allow(webmentions).to receive(:get_webmentions) do |targets, since_id, page_number|
        requests << [targets, since_id, page_number]

        lookup_result([refiled])
      end

      generator.generate(site)

      expect(requests.length).to eq(1)
      expect(requests.first).to eq([[page.uri], 9, 0])
    end

    it 'refuses a post with more URL spellings than one request may carry' do
      allow(page).to receive(:data).and_return({ 'redirect_from' => (1..60).map { |n| "/redirect-#{n}.html" } })

      expect { generator.generate(site) }.to raise_error(ArgumentError, /50/)
    end

    it 'follows the page count to the end' do
      pages = []
      allow(webmentions).to receive(:get_webmentions) do |_targets, _since_id, page_number|
        pages << page_number

        lookup_result(page_number.zero? ? [webmention] : [], total_pages: 2)
      end

      generator.generate(site)

      expect(pages).to eq([0, 1])
      expect(cached_mentions(page)).to have_key('12345')
    end

    it 'leaves a failed lookup to be retried rather than throttled' do
      allow(webmentions).to receive(:get_webmentions).and_return(lookup_result([], success: false))

      generator.generate(site)

      expect(caches.site_lookups.key?(page.url)).to be false
      expect(caches.incoming_webmentions.key?(page.url)).to be false
    end

    context 'with more than one post' do
      before do
        documents << other_page
      end

      it 'asks about them in one request' do
        generator.generate(site)

        expect(webmentions).to have_received(:get_webmentions).once
        expect(webmentions).to have_received(:get_webmentions).with([page.uri, other_page.uri], nil, 0)
      end

      it 'files a mention only against the post that asked about its target' do
        generator.generate(site)

        expect(cached_mentions(page)).to have_key('12345')
        expect(cached_mentions(other_page)).to be_nil
      end

      it 'cuts a batch by URL count rather than by post' do
        allow(page).to receive(:data).and_return({ 'redirect_from' => (1..30).map { |n| "/redirect-#{n}.html" } })
        allow(other_page).to receive(:data).and_return({ 'redirect_from' => (1..30).map { |n| "/other-redirect-#{n}.html" } })
        sizes = []
        allow(webmentions).to receive(:get_webmentions) do |targets, _since_id, _page_number|
          sizes << targets.length

          lookup_result([])
        end

        generator.generate(site)

        expect(sizes).to eq([31, 31])
      end

      it 'asks about a new post on its own, rather than letting it spoil the batch for the rest' do
        fresh = dated_page('/fresh.html', DateTime.now)
        documents << fresh
        # webmention.io files a page under the URL it resolved, which for a post it has
        # never answered for is one an answer cannot be matched against.
        refiled = webmention_for('9', 'https://example.com/fresh/')
        calls = []
        allow(webmentions).to receive(:get_webmentions) do |urls, _since_id, _page_number|
          calls << urls

          lookup_result(urls.include?(fresh.uri) ? [refiled] : [])
        end

        generator.generate(site)

        expect(calls).to contain_exactly([fresh.uri], [page.uri, other_page.uri])
        expect(cached_mentions(fresh)).to have_key('9')
      end

      it 'shares a request between new posts whose filings are already known' do
        recent_page = dated_page('/recent.html', DateTime.now)
        other_recent_page = dated_page('/other-recent.html', DateTime.now)
        [recent_page, other_recent_page].each do |recent|
          caches.incoming_webmentions.store(
            recent.url,
            { '100' => { 'raw' => { 'id' => 100, 'target' => recent.uri, 'verified_date' => '2025-10-18' } } }
          )
          documents << recent
        end

        generator.generate(site)

        expect(webmentions).to have_received(:get_webmentions).with([recent_page.uri, other_recent_page.uri], 100, 0)
      end

      it 'keeps posts with nothing cached out of a request with posts that have cached mentions' do
        caches.incoming_webmentions.store(
          page.url,
          { '100' => { 'raw' => { 'id' => 100, 'verified_date' => '2025-10-18' } } }
        )
        # Answer each request with what belongs to it, so the only thing under
        # test is how the posts were grouped.
        allow(webmentions).to receive(:get_webmentions) do |targets, _since_id, _page_number|
          lookup_result(targets.include?(page.uri) ? [webmention] : [])
        end

        generator.generate(site)

        expect(webmentions).to have_received(:get_webmentions).with([page.uri], 100, 0)
        expect(webmentions).to have_received(:get_webmentions).with([other_page.uri], nil, 0)
        expect(webmentions).to have_received(:get_webmentions).twice
      end

      it 'retries a request a post at a time when an answer names a URL that matches nothing' do
        stray = webmention_for('9', 'https://example.com/somewhere-else.html')
        calls = []
        allow(webmentions).to receive(:get_webmentions) do |targets, _since_id, _page_number|
          calls << targets

          lookup_result(calls.length == 1 ? [webmention, stray] : [webmention])
        end
        allow(Jekyll::WebmentionIO).to receive(:log)

        generator.generate(site)

        expect(calls).to eq([[page.uri, other_page.uri], [page.uri], [other_page.uri]])
        expect(Jekyll::WebmentionIO).to have_received(:log).with('info', /which is not a URL that was asked about/)
      end
    end
  end

  context 'when throttling lookups' do
    let(:page) { double('Jekyll::Page', url: '/page.html', data: {}, uri: 'https://example.com/page.html', date: DateTime.now) }

    before do
      documents << page
    end

    # Every band of post age throttles on its own delay, so each is a case here
    # rather than a copy of the same four statements.
    {
      'throttles posts from last week daily' => ['last_week', 'daily', 5, 1],
      'throttles posts from last month weekly' => ['last_month', 'weekly', 29, 7],
      'throttles posts from last year every two weeks' => ['last_year', 'every 2 weeks', 364, 14],
      'throttles old posts monthly' => ['older', 'monthly', 400, 31]
    }.each do |description, (band, delay, age, waited)|
      it description do
        config.parse({ 'throttle_lookups' => { band => delay } })
        allow(page).to receive(:date).and_return(DateTime.now - age)

        # The first lookup is not throttled, the second is, and the third is not
        # once the configured wait has passed.
        generator.generate(site)
        generator.generate(site)
        Timecop.travel(Date.today + waited) { generator.generate(site) }

        expect(webmentions).to have_received(:get_webmentions).twice
      end
    end
  end

  it 'honours pause_lookups setting' do
    config.parse({ 'pause_lookups' => true })
    generator.generate(site)
    expect(webmentions).not_to have_received(:get_webmentions)
  end
end
