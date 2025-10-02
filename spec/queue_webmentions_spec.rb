require 'spec_helper'

describe Jekyll::WebmentionIO::QueueWebmentions do
  before do
    Jekyll.logger.log_level = :error

    @config = SpecHelper::MockConfig.new
    @caches = SpecHelper::MockCaches.new
    @webmentions = SpecHelper::MockWebmentions.new

    Jekyll::WebmentionIO.bootstrap(nil, @config, @caches, nil, @webmentions)

    @generator = Jekyll::WebmentionIO::QueueWebmentions.new
  end

  it 'supports inline URLs' do
    target = 'http://www.test.com'
    page = SpecHelper::MockPage.new(
      url: 'foo.bar.baz',
      content: "This is a [test](#{target})"
    )

    @config.documents.append(page)

    @generator.generate

    expect(@caches.outgoing_webmentions).to match(page.uri => { target => false })
  end

  it 'supports in_reply_to front matter' do
    target = 'http://www.test.com'
    page = SpecHelper::MockPage.new(
      url: 'foo.bar.baz',
      data: { 'in_reply_to' => target }
    )

    @config.documents.append(page)

    @generator.generate

    expect(@caches.outgoing_webmentions).to match(page.uri => { target => false })
  end

  it 'supports bookmark_of front matter' do
    target = 'http://www.test.com'
    page = SpecHelper::MockPage.new(
      url: 'foo.bar.baz',
      data: { 'bookmark_of' => target }
    )

    @config.documents.append(page)

    @generator.generate

    expect(@caches.outgoing_webmentions).to match(page.uri => { target => false })
  end

  it 'supports syndicate_to front matter in post' do
    target = 'http://www.test.com'
    page = SpecHelper::MockPage.new(
      url: 'foo.bar.baz',
      data: { 'syndicate_to' => ['receiver'] }
    )

    @config.parse({ 'syndication' => { 'receiver' => { 'endpoint' => target } } })
    @config.documents.append(page)

    @generator.generate

    expect(@caches.outgoing_webmentions).to match(page.uri => { target => false })
  end

  it 'supports syndicate_to front matter in collection' do
    target = 'http://www.test.com'
    page = SpecHelper::MockPage.new(
      url: 'foo.bar.baz',
    )
    collection = Struct.new(:docs, :metadata).new([page], { 'syndicate_to' => ['receiver'] })

    @config.parse({ 'syndication' => { 'receiver' => { 'endpoint' => target } } })
    @config.documents.append(page)
    @config.collections['test'] = collection

    @generator.generate

    expect(@caches.outgoing_webmentions).to match(page.uri => { target => false })
  end

  it 'ignores shorturi if setting not enabled' do
    # In this case the full URI is used even if a shorturi is specified
    target = 'http://www.test.com'
    page = SpecHelper::MockPage.new(
      url: 'foo.bar.baz',
      data: { 'syndicate_to' => ['receiver'], 'shorturl' => 'shortie' }
    )

    @config.parse({ 'syndication' => { 'receiver' => { 'endpoint' => target } } })
    @config.documents.append(page)

    @generator.generate

    expect(@caches.outgoing_webmentions).to match(page.uri => { target => false })
  end

  it 'supports shorturi if setting enabled' do
    # In this case the shorturi is used as the source instead of the full uri
    target = 'http://www.test.com'
    page = SpecHelper::MockPage.new(
      url: 'foo.bar.baz',
      data: { 'syndicate_to' => ['receiver'], 'shorturl' => 'shortie' }
    )

    @config.parse({ 'syndication' => { 'receiver' => { 'endpoint' => target, 'shorturl' => true } } })
    @config.documents.append(page)

    @generator.generate

    expect(@caches.outgoing_webmentions).to match(page.data['shorturl'] => { target => false })
  end

  it 'supports fragment setting' do
    # In this case a fragment specifier is appended to the source uri
    target = 'http://www.test.com'
    page = SpecHelper::MockPage.new(
      url: 'foo.bar.baz',
      data: { 'syndicate_to' => ['receiver'] }
    )

    @config.parse({ 'syndication' => { 'receiver' => { 'endpoint' => target, 'fragment' => 'foo' } } })
    @config.documents.append(page)

    @generator.generate

    expect(@caches.outgoing_webmentions).to match("#{page.uri}#foo" => { target => false })
  end

  it 'honours pause_lookups setting' do
    target = 'http://www.test.com'
    page = SpecHelper::MockPage.new(
      url: 'foo.bar.baz',
      content: "This is a [test](#{target})"
    )

    @config.pause_lookups = true
    @config.documents.append(page)

    @generator.generate

    expect(@caches.outgoing_webmentions).to be_empty
  end

  it 'ignores mentions already sent' do
    target = 'http://www.test.com'
    page = SpecHelper::MockPage.new(
      url: 'foo.bar.baz',
      content: "This is a [test](#{target})"
    )

    @config.documents.append(page)

    @generator.generate
    @generator.generate

    expect(@caches.outgoing_webmentions).to match(page.uri => { target => false })
  end

  it 'rejects malformed url' do
    # From issue #178, using the sample URL '//_'
    target = '//_'
    page = SpecHelper::MockPage.new(
      url: 'foo.bar.baz',
      content: "This is a [test](#{target})"
    )

    @config.documents.append(page)

    @generator.generate

    expect(@caches.outgoing_webmentions).to be_empty
  end

  it 'ignores drafts' do
    target = 'http://www.test.com'
    page = SpecHelper::MockPage.new(
      url: 'foo.bar.baz',
      content: "This is a [test](#{target})",
      data: { 'draft' => true }
    )

    @config.documents.append(page)

    @generator.generate

    expect(@caches.outgoing_webmentions).to be_empty
  end

  it 'maps syndication frontmatter for single mention' do
    target = 'http://www.test.com'
    url = 'http://yadda.yadda'
    page = SpecHelper::MockPage.new(
      url: 'foo.bar.baz',
      content: "This is a [test](#{target})"
    )
    webmention = { target => { 'url' => url } }

    @config.parse(
      {
        'syndication' => {
          'receiver' => {
            'endpoint' => target,
            'response_mapping' => { 'syndication' => '$.url' }
          }
        }
      }
    )
    @caches.outgoing_webmentions[page.uri] = webmention
    @config.documents.append(page)

    @generator.generate

    expect(@caches.outgoing_webmentions).to match({ page.uri => webmention })
    expect(page.data['syndication']).to match(url)
  end

  it 'handles bad syndication remapping rule' do
    # If the returned payload doesn't contain a given key, we should ignore it
    target = 'http://www.test.com'
    page = SpecHelper::MockPage.new(
      url: 'foo.bar.baz',
      content: "This is a [test](#{target})"
    )
    webmention = { target => { 'foo' => 'bar' } }

    @config.parse(
      {
        'syndication' => {
          'receiver' => {
            'endpoint' => target,
            'response_mapping' => { 'syndication' => '$.url' }
          }
        }
      }
    )
    @caches.outgoing_webmentions[page.uri] = webmention
    @config.documents.append(page)

    @generator.generate

    expect(@caches.outgoing_webmentions).to match({ page.uri => webmention })
    expect(page.data['syndication']).to be_nil
  end

  it 'combines syndication front matter' do
    # If there are multiple responses that return the same key, we combine
    # them into an array
    first_target = 'http://www.test.com'
    second_target = 'http://blah.com'

    first_url = 'http://yadda.yadda'
    second_url = 'http://etc.etc'

    page = SpecHelper::MockPage.new(
      url: 'foo.bar.baz',
      content: "This is a [test](#{first_target}) and [another test](#{second_target})"
    )

    webmentions = { 
      first_target => { 'url' => first_url },
      second_target => { 'url' => second_url }
    }

    @config.parse(
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

    @caches.outgoing_webmentions[page.uri] = webmentions
    @config.documents.append(page)

    @generator.generate

    expect(@caches.outgoing_webmentions).to match({ page.uri => webmentions })

    expect(page.data['syndication']).to contain_exactly(first_url, second_url)
  end
end
