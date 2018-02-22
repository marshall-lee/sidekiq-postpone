$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'sidekiq/postpone'
require 'support/sidekiq_helper'

require 'sidekiq/api'
require 'sidekiq/redis_connection'
REDIS_URL = ENV['REDIS_URL'] || 'redis://localhost/15'
REDIS = Sidekiq::RedisConnection.create(:url => REDIS_URL, :namespace => 'testy')

Sidekiq.configure_client do |config|
  config.redis = { :url => REDIS_URL, :namespace => 'sidekiq-postpone-testy' }
end

RSpec.configure do |c|
  c.include SidekiqHelper
  c.after(:each) { clear_sidekiq_workers }
  c.after(:each) do
    Sidekiq.redis { |namespaced| namespaced.redis.flushall }
  end

  c.order = :random
  Kernel.srand c.seed
end
