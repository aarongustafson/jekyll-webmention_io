# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_context 'webmention_tag_context' do
  include_context 'webmention_io_stubs'

  let(:url) { 'http://www.test.com' }
  let(:context) { Struct.new(:page, :line_number, :registers).new(Struct.new(:url).new(url), 1, {}) }
  let(:incoming_webmentions) { {} }
  let(:template) do
    <<~TEMPLATE
      {% for webmention in webmentions %}
      {{ webmention.content }}
      {% endfor %}
    TEMPLATE
  end

  before do
    allow(caches).to receive(:incoming_webmentions).and_return(incoming_webmentions)

    allow(templates).to receive(:template_contents).and_return(template)
  end
end

RSpec.shared_examples 'a webmention tag' do
  include_context 'webmention_tag_context'

  it 'renders a single tag' do
    content = 'Foo Bar Baz'
    incoming_webmentions[url] = [{ 'id' => 1, 'type' => type, 'content' => content }]

    tag = described_class.parse(nil, 'page.url', nil, context)
    result = tag.render(context)

    expect(result).to match(content)
  end

  it 'ignores other webmention types' do
    incoming_webmentions[url] = [{ 'id' => 1, 'type' => 'foo', 'content' => 'test' }]

    tag = described_class.parse(nil, 'page.url', nil, context)
    result = tag.render(context)

    expect(result).to be_empty
  end
end

RSpec.describe Jekyll::WebmentionIO::WebmentionBookmarksTag do
  it_behaves_like 'a webmention tag' do
    let(:type) { 'bookmark' }
  end
end

RSpec.describe Jekyll::WebmentionIO::WebmentionLikesTag do
  it_behaves_like 'a webmention tag' do
    let(:type) { 'like' }
  end
end

RSpec.describe Jekyll::WebmentionIO::WebmentionLinksTag do
  it_behaves_like 'a webmention tag' do
    let(:type) { 'link' }
  end
end

RSpec.describe Jekyll::WebmentionIO::WebmentionPostsTag do
  it_behaves_like 'a webmention tag' do
    let(:type) { 'post' }
  end
end

RSpec.describe Jekyll::WebmentionIO::WebmentionRepliesTag do
  it_behaves_like 'a webmention tag' do
    let(:type) { 'reply' }
  end
end

RSpec.describe Jekyll::WebmentionIO::WebmentionRepostsTag do
  it_behaves_like 'a webmention tag' do
    let(:type) { 'repost' }
  end
end

RSpec.describe Jekyll::WebmentionIO::WebmentionRsvpsTag do
  it_behaves_like 'a webmention tag' do
    let(:type) { 'rsvp' }
  end
end

RSpec.describe Jekyll::WebmentionIO::WebmentionsTag do
  include_context 'webmention_tag_context'

  before do
    incoming_webmentions[url] = [
      { 'id' => 1, 'type' => 'like', 'content' => 'Number 1' },
      { 'id' => 2, 'type' => 'bookmark', 'content' => 'Number 2' },
      { 'id' => 3, 'type' => 'reply', 'content' => 'Number 3' }
    ]
  end

  it 'renders all tags' do
    tag = described_class.parse(nil, 'page.url', nil, context)
    result = tag.render(context)

    expect(result).to match('Number 1\nNumber 2\nNumber 3')
  end

  it 'supports filtering for a single tag' do
    tag = described_class.parse(nil, 'page.url likes', nil, context)
    result = tag.render(context)

    expect(result).to match('Number 1')
  end

  it 'supports filtering for multiple tags' do
    tag = described_class.parse(nil, 'page.url likes replies', nil, context)
    result = tag.render(context)

    expect(result).to match('Number 1\nNumber 3')
  end
end
