require 'spec_helper'

describe Jekyll::WebmentionIO do
  let(:page)      { make_page }
  let(:site)      { make_site }
  let(:post)      { make_post }
  let(:context)   { make_context(page: page, site: site) }
  let(:all)       { 'webmentions' }
  let(:count)     { 'webmention_count' }
  let(:like)      { 'webmention_likes' }
  let(:reply)     { 'webmention_replies' }
  let(:repost)    { 'webmention_reposts' }
  let(:url)       { '' }
  let(:o_all)     { Liquid::Template.parse("{% #{tag} #{url} %}").render!(context, {}) }
  let(:o_count)   { Liquid::Template.parse("{% #{tag} #{url} %}").render!(context, {}) }
  let(:o_like)    { Liquid::Template.parse("{% #{tag} #{url} %}").render!(context, {}) }
  let(:o_reply)   { Liquid::Template.parse("{% #{tag} #{url} %}").render!(context, {}) }
  let(:o_repost)  { Liquid::Template.parse("{% #{tag} #{url} %}").render!(context, {}) }

  before do
    Jekyll.logger.log_level = :error
  end

  it 'builds' do
    expect(o_all).to match(//i)
  end

  it 'outputs valid HTML' do
    site.process
    options = {
      check_html: true,
      checks_to_ignore: %w[ScriptCheck LinkCheck ImageCheck]
    }
    status = HTMLProofer.check_directory(dest_dir, options).run
    expect(status).to eql(true)
  end
end
