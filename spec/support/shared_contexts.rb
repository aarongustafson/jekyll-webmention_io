# frozen_string_literal: true

RSpec.shared_context 'webmention_io_stubs' do
  let(:config) { Jekyll::WebmentionIO::Config.new }
  let(:caches) { instance_double('Jekyll::WebmentionIO::Caches') }
  let(:webmentions) { instance_double('Jekyll::WebmentionIO::Webmentions') }
  let(:policy) { Jekyll::WebmentionIO::WebmentionPolicy.new(config, caches) }
  let(:site) { instance_double('Jekyll::Site') }

  before do
    Jekyll.logger.log_level = :error

    allow(Jekyll::WebmentionIO).to receive(:config).and_return(config)
    allow(Jekyll::WebmentionIO).to receive(:caches).and_return(caches)
    allow(Jekyll::WebmentionIO).to receive(:webmentions).and_return(webmentions)
    allow(Jekyll::WebmentionIO).to receive(:policy).and_return(policy)
    allow(Jekyll::WebmentionIO).to receive(:site).and_return(site)
  end
end
