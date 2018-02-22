# frozen_string_literal: true

require "sidekiq"
require "sidekiq/postpone/version"
require "sidekiq/postpone/core_ext"

class Sidekiq::Postpone
  def initialize(*client_args)
    @client_args = client_args
    setup_queues
    setup_schedule
  end

  def wrap
    start
    yield(self).tap do
      stop
      flush
    end
  ensure
    stop
  end

  def self.wrap(&block)
    new.wrap(&block)
  end

  def push(payloads)
    if payloads.first['at']
      @schedule.concat(payloads)
    else
      q = payloads.first['queue']
      @queues[q].concat(payloads)
    end
  end

  def clear!
    @queues.clear
    @schedule.clear
  end

  private

  def flush
    return if @queues.empty? && @schedule.empty?
    client = Sidekiq::Client.new(*@client_args)
    raw_push = client.method(:raw_push)
    @queues.each_value(&raw_push)
    raw_push.(@schedule) unless @schedule.empty?
  end

  def start
    if Thread.current[:sidekiq_postpone]
      raise 'Nested Sidekiq::Postpone is not supported'
    end

    Thread.current[:sidekiq_postpone] = self
  end

  def stop
    Thread.current[:sidekiq_postpone] = nil
  end

  def setup_queues
    @queues = Hash.new do |hash, key|
      hash[key] = []
    end
  end

  def setup_schedule
    @schedule = []
  end
end
