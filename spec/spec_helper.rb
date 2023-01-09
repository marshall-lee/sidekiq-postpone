$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'sidekiq/postpone'
require 'support/sidekiq_helper'

require 'sidekiq/api'
require 'sidekiq/redis_connection'
redis_url = ENV['REDIS_URL'] || 'redis://localhost/15'

Sidekiq.configure_client do |config|
  config.redis = { :url => redis_url }
end

RSpec.configure do |c|
  c.include SidekiqHelper
  c.after(:each) { remove_sidekiq_workers }
  c.after(:each) do
    Sidekiq::RetrySet.new.clear
    Sidekiq::ScheduledSet.new.clear
    Sidekiq::DeadSet.new.clear
    Sidekiq::Queue.all.map(&:clear)
  end

  c.order = :random
  Kernel.srand c.seed
end
