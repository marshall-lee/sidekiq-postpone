require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec) do |rspec|
  rspec.exclude_pattern = 'spec/sidekiq-postpone_testing_integration_spec.rb'
end

namespace :spec do
  RSpec::Core::RakeTask.new(:sidekiq_testing_integration) do |rspec|
    rspec.pattern = 'spec/sidekiq-postpone_testing_integration_spec.rb'
  end
end

task :default => :spec
