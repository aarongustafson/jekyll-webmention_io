# frozen_string_literal: true

require 'spec_helper'

describe Jekyll::WebmentionIO::WebmentionCollector do
  include_context 'webmention_io_stubs'
  include_context 'webmention lookup results'

  let(:collector) { described_class.new(webmentions) }
  let(:page) { double('Jekyll::Page', url: '/page.html') }
  let(:other_page) { double('Jekyll::Page', url: '/other.html') }

  def target(*urls, post: page, since_id: nil, canonical_urls: [])
    Jekyll::WebmentionIO::Target.new(post: post, urls: urls, since_id: since_id, canonical_urls: canonical_urls)
  end

  before do
    allow(webmentions).to receive(:get_webmentions).and_return(lookup_result([]))
  end

  it 'holds a post with nothing new as an empty list' do
    expect(collector.lookup([target('https://example.com/page.html')])).to eq('/page.html' => [])
  end

  it 'asks about every URL in the batch, from the oldest wm-id it holds' do
    collector.lookup(
      [
        target('https://example.com/page.html', since_id: 100),
        target('https://example.com/other.html', post: other_page, since_id: 40)
      ]
    )

    expect(webmentions).to have_received(:get_webmentions).with(
      ['https://example.com/page.html', 'https://example.com/other.html'], 40, 0
    )
  end

  it 'returns nothing at all when the lookup fails' do
    allow(webmentions).to receive(:get_webmentions).and_return(lookup_result([], success: false))

    expect(collector.lookup([target('https://example.com/page.html')])).to eq({})
  end

  it 'says that a failed lookup leaves the posts to be asked about again' do
    allow(webmentions).to receive(:get_webmentions).and_return(lookup_result([], success: false))
    allow(Jekyll::WebmentionIO).to receive(:log)

    collector.lookup([target('https://example.com/page.html')])

    expect(Jekyll::WebmentionIO).to have_received(:log).with('info', /the lookup failed on page 0/)
  end

  it 'matches a URL the answer names without its fragment' do
    item = webmention_for('1', 'https://example.com/page.html#comment')
    allow(webmentions).to receive(:get_webmentions).and_return(lookup_result([item]))

    expect(collector.lookup([target('https://example.com/page.html')])).to eq('/page.html' => [item])
  end

  it 'files a mention once when a post answers to the same URL twice' do
    item = webmention_for('1', 'https://example.com/page.html')
    allow(webmentions).to receive(:get_webmentions).and_return(lookup_result([item]))

    collected = collector.lookup(
      [target('https://example.com/page.html', canonical_urls: ['https://example.com/page.html'])]
    )

    expect(collected).to eq('/page.html' => [item])
  end

  it 'refuses a batch holding more URLs than one request may carry' do
    limit = described_class::MAX_URLS_PER_REQUEST
    batch = (1..(limit + 1)).map { |n| target("https://example.com/#{n}") }

    expect { collector.lookup(batch) }.to raise_error(ArgumentError, /50/)
  end

  it 'refuses a batch mixing posts with and without cached mentions' do
    batch = [
      target('https://example.com/page.html', since_id: 100),
      target('https://example.com/other.html', post: other_page)
    ]

    expect { collector.lookup(batch) }.to raise_error(ArgumentError, /since_id/)
  end

  it 'asks about a batch of one without fetching the same page twice' do
    item = webmention_for('9', 'https://example.com/somewhere-else.html')
    calls = []
    allow(webmentions).to receive(:get_webmentions) do |urls, _since_id, _page_number|
      calls << urls

      lookup_result([item])
    end

    collected = collector.lookup([target('https://example.com/page.html')])

    expect(calls).to eq([['https://example.com/page.html']])
    expect(collected).to eq('/page.html' => [item])
  end

  context 'when an answer names a URL that matches nothing' do
    let(:stray) { webmention_for('9', 'https://example.com/somewhere-else.html') }
    let(:batch) do
      [
        target('https://example.com/page.html'),
        target('https://example.com/other.html', post: other_page)
      ]
    end

    it 'files what a post is told against that post, whatever URL it names' do
      calls = []
      allow(webmentions).to receive(:get_webmentions) do |urls, _since_id, _page_number|
        calls << urls

        lookup_result(calls.length == 1 ? [stray] : [webmention_for('9', 'https://example.com/somewhere-else.html')])
      end

      collected = collector.lookup(batch)

      expect(collected['/page.html'].length).to eq(1)
      expect(collected['/other.html'].length).to eq(1)
    end

    it 'leaves out a post whose own request failed' do
      allow(webmentions).to receive(:get_webmentions) do |urls, _since_id, _page_number|
        if urls == ['https://example.com/other.html']
          lookup_result([], success: false)
        else
          lookup_result([stray])
        end
      end

      expect(collector.lookup(batch)).to eq('/page.html' => [stray])
    end

    it 'returns nothing when every post asked one at a time fails' do
      calls = 0
      allow(webmentions).to receive(:get_webmentions) do |_urls, _since_id, _page_number|
        calls += 1

        calls == 1 ? lookup_result([stray]) : lookup_result([], success: false)
      end

      expect(collector.lookup(batch)).to eq({})
    end
  end
end
