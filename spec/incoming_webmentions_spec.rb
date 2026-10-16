# frozen_string_literal: true

require 'spec_helper'

describe Jekyll::WebmentionIO::IncomingWebmentions do
  def mention(id, target, verified_at: nil)
    raw = { 'id' => id, 'target' => target }
    raw['verified_date'] = verified_at if verified_at

    { 'raw' => raw }
  end

  let(:mentions) do
    {
      '1' => mention(1, 'https://example.com/page.html'),
      '2' => mention(2, 'https://example.com/page.html')
    }
  end

  # Cache files written before the mentions were keyed by id hold them as a list.
  it 'reads a cache file that held the mentions as a plain list' do
    cache = described_class.new('/page.html', [mention(1, 'https://example.com/page.html')])

    expect(cache.highest_id).to eq(1)
    expect(cache.canonical_urls).to eq(['https://example.com/page.html'])
  end

  describe '#canonical_urls' do
    it 'reports the URL the mentions came back under' do
      cache = described_class.new('/page.html', mentions)

      expect(cache.canonical_urls).to eq(['https://example.com/page.html'])
    end

    it 'keeps them oldest first, so the last one is the newest answer' do
      cache = described_class.new(
        '/page.html',
        { '1' => mention(1, 'https://example.com/old.html'), '2' => mention(2, 'https://example.com/new.html') }
      )

      expect(cache.canonical_urls).to eq(['https://example.com/old.html', 'https://example.com/new.html'])
    end

    it 'keeps the URLs already held as the mentions come back under new ones' do
      first = described_class.new(
        '/page.html',
        {
          'webmentions' => { '1' => mention(1, 'https://example.com/old.html') },
          'canonical_urls' => ['https://example.com/moved-from.html']
        }
      )
      stored = first.to_val

      second = described_class.new(
        '/page.html',
        stored.merge('webmentions' => stored['webmentions'].merge('2' => mention(2, 'https://example.com/new.html')))
      )

      expect(second.canonical_urls).to eq(
        ['https://example.com/moved-from.html', 'https://example.com/old.html', 'https://example.com/new.html']
      )
    end

    it 'is empty when nothing is cached for the post' do
      expect(described_class.new('/page.html', nil).canonical_urls).to eq([])
    end
  end

  describe '#highest_id' do
    it 'is nil when nothing is cached for the post' do
      expect(described_class.new('/page.html', nil).highest_id).to be_nil
    end
  end

  describe '#last_heard_at' do
    it 'is the newest date held, whatever order they were cached in' do
      cache = described_class.new(
        '/page.html',
        {
          '1' => mention(1, 'https://example.com/page.html', verified_at: '2025-10-19T00:00:00+00:00'),
          '2' => mention(2, 'https://example.com/page.html', verified_at: '2025-10-17T00:00:00+00:00'),
          '3' => mention(3, 'https://example.com/page.html', verified_at: '2025-10-18T00:00:00+00:00')
        }
      )

      expect(cache.last_heard_at).to eq(Date.new(2025, 10, 19))
    end

    it 'is nil when the mentions carry no date' do
      expect(described_class.new('/page.html', mentions).last_heard_at).to be_nil
    end

    it 'is nil when a mention carries a date it cannot read' do
      cache = described_class.new(
        '/page.html',
        { '1' => mention(1, 'https://example.com/page.html', verified_at: 'not a date') }
      )

      expect(cache.last_heard_at).to be_nil
    end

    it 'is nil when nothing is cached for the post' do
      expect(described_class.new('/page.html', nil).last_heard_at).to be_nil
    end
  end

  describe '#to_val' do
    it 'writes the mentions alongside the URLs they came back under' do
      cache = described_class.new('/page.html', mentions)

      expect(cache.to_val).to eq(
        'webmentions' => mentions,
        'canonical_urls' => ['https://example.com/page.html']
      )
    end
  end
end
