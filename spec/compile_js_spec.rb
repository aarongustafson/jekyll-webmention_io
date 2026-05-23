# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe Jekyll::WebmentionIO::CompileJS do
  include_context 'webmention_io_stubs'

  let(:tmp) { Dir.mktmpdir('compile_js_spec') }
  let(:site) { instance_double('Jekyll::Site') }
  let(:generator) { described_class.new }
  let(:compiled_js) { File.read(File.join(tmp, 'js', 'JekyllWebmentionIO.js')) }

  before do
    # uglify off so the assertions can read the un-minified output (and we don't
    # need a JS runtime); deploy off so we don't touch site.static_files.
    config.parse({ 'api_url' => 'http://localhost:9999/api',
                   'js' => { 'uglify' => false, 'deploy' => false } })
    allow(site).to receive(:config).and_return({})
    allow(site).to receive(:in_source_dir).and_return(tmp)
  end

  after { FileUtils.rm_rf(tmp) }

  it 'injects the configured api_base onto the global' do
    generator.generate(site)

    expect(compiled_js).to include('window.JekyllWebmentionIO.api_base = "http://localhost:9999/api"')
  end

  it 'sets api_base before the loader reads it' do
    generator.generate(site)

    assignment = compiled_js.index('api_base =')
    usage = compiled_js.index('api_base ||')

    expect(assignment).to be < usage
  end
end
