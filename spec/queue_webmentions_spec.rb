# frozen_string_literal: true

require 'spec_helper'

describe Jekyll::WebmentionIO::QueueWebmentions do
  include_context 'webmention_io_stubs'

  let(:outgoing_webmentions_cache) { {} }
  let(:documents) { [] }
  let(:collections) { {} }

  before do
    allow(config).to receive(:documents).and_return(documents)
    allow(config).to receive(:collections).and_return(collections)
    allow(config).to receive(:site_url).and_return('http://example.com')

    allow(caches).to receive(:outgoing_webmentions).and_return(outgoing_webmentions_cache)
    allow(outgoing_webmentions_cache).to receive(:write)
  end

  let(:generator) { described_class.new }

  it 'supports inline URLs' do
    target = 'http://www.test.com'
    page = instance_double(
      Jekyll::Page,
      url: 'foo.bar.baz',
      content: "This is a [test](#{target})",
      data: {},
      path: 'foo.bar.baz'
    )

    documents.append(page)

    generator.generate

    expect(outgoing_webmentions_cache).to match("http://example.com/#{page.url}" => { target => false })
  end

  it 'supports in_reply_to front matter' do
    target = 'http://www.test.com'
    page = instance_double(
      Jekyll::Page,
      url: 'foo.bar.baz',
      content: '',
      data: { 'in_reply_to' => target },
      path: 'foo.bar.baz'
    )

    documents.append(page)

    generator.generate

    expect(outgoing_webmentions_cache).to match("http://example.com/#{page.url}" => { target => false })
  end

  it 'supports bookmark_of front matter' do
    target = 'http://www.test.com'
    page = instance_double(
      Jekyll::Page,
      url: 'foo.bar.baz',
      content: '',
      data: { 'bookmark_of' => target },
      path: 'foo.bar.baz'
    )

    documents.append(page)

    generator.generate

    expect(outgoing_webmentions_cache).to match("http://example.com/#{page.url}" => { target => false })
  end

  it 'supports syndicate_to front matter in post' do
    target = 'http://www.test.com'
    page = instance_double(
      Jekyll::Page,
      url: 'foo.bar.baz',
      content: '',
      data: { 'syndicate_to' => ['receiver'] },
      path: 'foo.bar.baz'
    )

    config.parse({ 'syndication' => { 'receiver' => { 'endpoint' => target } } })
    documents.append(page)

    generator.generate

    expect(outgoing_webmentions_cache).to match("http://example.com/#{page.url}" => { target => false })
  end

  it 'supports syndicate_to front matter in collection' do
    target = 'http://www.test.com'
    page = instance_double(
      Jekyll::Page,
      url: 'foo.bar.baz',
      content: '',
      data: {},
      path: 'foo.bar.baz'
    )

    collection = Struct.new(:docs, :metadata).new([page], { 'syndicate_to' => ['receiver'] })

    config.parse({ 'syndication' => { 'receiver' => { 'endpoint' => target } } })
    documents.append(page)
    collections['test'] = collection

    generator.generate

    expect(outgoing_webmentions_cache).to match("http://example.com/#{page.url}" => { target => false })
  end

  it 'ignores shorturi if setting not enabled' do
    # In this case the full URI is used even if a shorturi is specified
    target = 'http://www.test.com'
    page = instance_double(
      Jekyll::Page,
      url: 'foo.bar.baz',
      content: '',
      data: { 'syndicate_to' => ['receiver'], 'shorturl' => 'shortie' },
      path: 'foo.bar.baz'
    )

    config.parse({ 'syndication' => { 'receiver' => { 'endpoint' => target } } })
    documents.append(page)

    generator.generate

    expect(outgoing_webmentions_cache).to match("http://example.com/#{page.url}" => { target => false })
  end

  it 'supports shorturi if setting enabled' do
    # In this case the shorturi is used as the source instead of the full uri
    target = 'http://www.test.com'
    page = instance_double(
      Jekyll::Page,
      url: 'foo.bar.baz',
      content: '',
      data: { 'syndicate_to' => ['receiver'], 'shorturl' => 'shortie' },
      path: 'foo.bar.baz'
    )

    config.parse({ 'syndication' => { 'receiver' => { 'endpoint' => target, 'shorturl' => true } } })
    documents.append(page)

    generator.generate

    expect(outgoing_webmentions_cache).to match(page.data['shorturl'] => { target => false })
  end

  it 'supports fragment setting' do
    # In this case a fragment specifier is appended to the source uri
    target = 'http://www.test.com'
    page = instance_double(
      Jekyll::Page,
      url: 'foo.bar.baz',
      content: '',
      data: { 'syndicate_to' => ['receiver'] },
      path: 'foo.bar.baz'
    )

    config.parse({ 'syndication' => { 'receiver' => { 'endpoint' => target, 'fragment' => 'foo' } } })
    documents.append(page)

    generator.generate

    expect(outgoing_webmentions_cache).to match("http://example.com/#{page.url}#foo" => { target => false })
  end

  it 'honours pause_lookups setting' do
    target = 'http://www.test.com'
    page = instance_double(
      Jekyll::Page,
      url: 'foo.bar.baz',
      content: "This is a [test](#{target})",
      data: {},
      path: 'foo.bar.baz'
    )

    config.parse({ 'pause_lookups' => true })
    documents.append(page)

    generator.generate

    expect(outgoing_webmentions_cache).to be_empty
  end

  it 'ignores mentions already sent' do
    target = 'http://www.test.com'
    page = instance_double(
      Jekyll::Page,
      url: 'foo.bar.baz',
      content: "This is a [test](#{target})",
      data: {},
      path: 'foo.bar.baz'
    )

    documents.append(page)

    generator.generate
    generator.generate

    expect(outgoing_webmentions_cache).to match("http://example.com/#{page.url}" => { target => false })
  end

  it 'rejects malformed url' do
    # From issue #178, using the sample URL '//_'
    target = '//_'
    page = instance_double(
      Jekyll::Page,
      url: 'foo.bar.baz',
      content: "This is a [test](#{target})",
      data: {},
      path: 'foo.bar.baz'
    )

    documents.append(page)

    generator.generate

    expect(outgoing_webmentions_cache).to be_empty
  end

  it 'ignores drafts' do
    target = 'http://www.test.com'
    page = instance_double(
      Jekyll::Page,
      url: 'foo.bar.baz',
      content: "This is a [test](#{target})",
      data: { 'draft' => true },
      path: 'foo.bar.baz'
    )

    documents.append(page)

    generator.generate

    expect(outgoing_webmentions_cache).to be_empty
  end

  it 'maps syndication frontmatter for single mention' do
    target = 'http://www.test.com'
    url = 'http://yadda.yadda'
    page = instance_double(
      Jekyll::Page,
      url: 'foo.bar.baz',
      content: "This is a [test](#{target})",
      data: {},
      path: 'foo.bar.baz'
    )
    webmention = { target => { 'url' => url } }

    config.parse(
      {
        'syndication' => {
          'receiver' => {
            'endpoint' => target,
            'response_mapping' => { 'syndication' => '$.url' }
          }
        }
      }
    )
    outgoing_webmentions_cache["http://example.com/#{page.url}"] = webmention
    documents.append(page)

    generator.generate

    expect(outgoing_webmentions_cache).to match({ "http://example.com/#{page.url}" => webmention })
    expect(page.data['syndication']).to match(url)
  end

  it 'maps syndication frontmatter when pause_lookups is set' do
    target = 'http://www.test.com'
    url = 'http://yadda.yadda'
    page = instance_double(
      Jekyll::Page,
      url: 'foo.bar.baz',
      content: "This is a [test](#{target})",
      data: {},
      path: 'foo.bar.baz'
    )
    webmention = { target => { 'url' => url } }

    config.parse(
      {
        'pause_lookups' => true,
        'syndication' => {
          'receiver' => {
            'endpoint' => target,
            'response_mapping' => { 'syndication' => '$.url' }
          }
        }
      }
    )

    outgoing_webmentions_cache["http://example.com/#{page.url}"] = webmention
    documents.append(page)

    generator.generate

    expect(outgoing_webmentions_cache).to match({ "http://example.com/#{page.url}" => webmention })
    expect(page.data['syndication']).to match(url)
  end

  it 'handles bad syndication remapping rule' do
    # If the returned payload doesn't contain a given key, we should ignore it
    target = 'http://www.test.com'
    page = instance_double(
      Jekyll::Page,
      url: 'foo.bar.baz',
      content: "This is a [test](#{target})",
      data: {},
      path: 'foo.bar.baz'
    )
    webmention = { target => { 'foo' => 'bar' } }

    config.parse(
      {
        'syndication' => {
          'receiver' => {
            'endpoint' => target,
            'response_mapping' => { 'syndication' => '$.url' }
          }
        }
      }
    )
    outgoing_webmentions_cache["http://example.com/#{page.url}"] = webmention
    documents.append(page)

    generator.generate

    expect(outgoing_webmentions_cache).to match({ "http://example.com/#{page.url}" => webmention })
    expect(page.data['syndication']).to be_nil
  end

  it 'combines syndication front matter' do
    # If there are multiple responses that return the same key, we combine
    # them into an array
    first_target = 'http://www.test.com'
    second_target = 'http://blah.com'

    first_url = 'http://yadda.yadda'
    second_url = 'http://etc.etc'

    page = instance_double(
      Jekyll::Page,
      url: 'foo.bar.baz',
      content: "This is a [test](#{first_target}) and [another test](#{second_target})",
      data: {},
      path: 'foo.bar.baz'
    )

    webmentions = {
      first_target => { 'url' => first_url },
      second_target => { 'url' => second_url }
    }

    config.parse(
      {
        'syndication' => {
          'receiver' => {
            'endpoint' => first_target,
            'response_mapping' => { 'syndication' => '$.url' }
          },
          'other' => {
            'endpoint' => second_target,
            'response_mapping' => { 'syndication' => '$.url' }
          }
        }
      }
    )

    outgoing_webmentions_cache["http://example.com/#{page.url}"] = webmentions
    documents.append(page)

    generator.generate

    expect(outgoing_webmentions_cache).to match({ "http://example.com/#{page.url}" => webmentions })

    expect(page.data['syndication']).to contain_exactly(first_url, second_url)
  end
end
