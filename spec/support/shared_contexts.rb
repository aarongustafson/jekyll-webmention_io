# frozen_string_literal: true

RSpec.shared_context 'webmention_io_stubs' do
  let(:config) { Jekyll::WebmentionIO::Config.new }
  let(:caches) { instance_double('Jekyll::WebmentionIO::Caches') }
  let(:webmentions) { instance_double('Jekyll::WebmentionIO::Webmentions') }
  let(:policy) { Jekyll::WebmentionIO::WebmentionPolicy.new(config, caches) }
  let(:site) { instance_double('Jekyll::Site') }
  let(:templates) { Jekyll::WebmentionIO::Templates.new(nil) }

  before do
    Jekyll.logger.log_level = :error

    allow(Jekyll::WebmentionIO).to receive(:config).and_return(config)
    allow(Jekyll::WebmentionIO).to receive(:caches).and_return(caches)
    allow(Jekyll::WebmentionIO).to receive(:webmentions).and_return(webmentions)
    allow(Jekyll::WebmentionIO).to receive(:policy).and_return(policy)
    allow(Jekyll::WebmentionIO).to receive(:site).and_return(site)
    allow(Jekyll::WebmentionIO).to receive(:templates).and_return(templates)
  end
end

# The client answers a lookup with a Result rather than a bare list of mentions, so
# that a caller can tell "nothing new" apart from "the call failed"; the specs answer
# with the same shape.
RSpec.shared_context 'webmention lookup results' do
  def lookup_result(items, total_pages: 1, success: true)
    Jekyll::WebmentionIO::Webmentions::Result.new(items: items, total_pages: total_pages, success: success)
  end

  def webmention_for(id, target)
    raw = {
      'id' => id,
      'source' => 'http://source.com',
      'target' => target,
      'verified_date' => '2025-10-19T00:00:00+00:00',
      'data' => {}
    }
    item = Jekyll::WebmentionIO::WebmentionItem.new(raw)
    allow(item).to receive(:to_hash).and_return({ 'id' => id, 'raw' => raw })

    item
  end
end
