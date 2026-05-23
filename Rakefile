# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

# Fast unit suite: everything except the end-to-end smoke tests.
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = '--tag ~integration'
end

# End-to-end smoke test. Boots local WEBrick servers to stand in for the
# webmention receiver and the webmention.io API -- no external services.
RSpec::Core::RakeTask.new(:integration) do |t|
  t.pattern = 'spec/integration/**/*_spec.rb'
  t.rspec_opts = '--tag integration'
end

task default: %i[spec integration]

# Coverage-enabled test tasks
namespace :coverage do
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.rspec_opts = '--tag ~integration'
    ENV['COVERAGE'] = 'true'
  end

  RSpec::Core::RakeTask.new(:integration) do |t|
    t.pattern = 'spec/integration/**/*_spec.rb'
    t.rspec_opts = '--tag integration'
    ENV['COVERAGE'] = 'true'
  end

  desc 'Run all tests with coverage'
  task all: %i[spec integration]
end

desc 'Run all tests with coverage (shorthand)'
task coverage: 'coverage:all'
