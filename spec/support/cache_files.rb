# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

# Real cache files in a throwaway folder. Anything that touches a cache gets the
# objects the plugin really uses rather than a stand-in, so a spec exercises the
# wrapper as well as its consumer. The Caches class is a singleton, hence the
# resets on both sides of an example.
RSpec.shared_context 'cache files' do
  let(:cache_folder) { Dir.mktmpdir('jekyll_webmention_io_spec') }
  let(:caches) { Jekyll::WebmentionIO::Caches.new(double('Config', cache_folder: cache_folder)) }

  before do
    Jekyll::WebmentionIO::Caches.reset
    allow(Jekyll::WebmentionIO).to receive(:caches).and_return(caches)
  end

  after do
    Jekyll::WebmentionIO::Caches.reset
    FileUtils.rm_rf(cache_folder)
  end
end
