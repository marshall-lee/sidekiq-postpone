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

  def wrap(join_parent: true, flush: true)
    enter!
    begin
      yield self
    rescue
      clear!
      raise
    end.tap do
      if join_parent && (parent = Thread.current[:sidekiq_postpone_stack][-2])
        join!(parent)
      elsif flush
        @flush_on_leave = true
      end
    end
  ensure
    leave!
  end

  def self.wrap(*client_args, **kwargs, &block)
    new(*client_args).wrap(**kwargs, &block)
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

  def flush!
    current_postpone = Thread.current[:sidekiq_postpone]
    return if empty?

    Thread.current[:sidekiq_postpone] = nil # activate real raw_push

    client = Sidekiq::Client.new(*@client_args)

    @queues.each_value { |item| client.raw_push(item) }
    client.raw_push(@schedule) unless @schedule.empty?

    clear!
  ensure
    Thread.current[:sidekiq_postpone] = current_postpone
  end

  def join!(other)
    return if empty?

    @queues.each do |name, payloads|
      other.queues[name].concat(payloads)
    end
    other.schedule.concat(@schedule)

    clear!
  end

  def empty?
    @queues.empty? && @schedule.empty?
  end

  def jids
    [*@queues.values.flatten(1), *@schedule].map! { |j| j['jid'] }
  end

  protected

  attr_reader :queues, :schedule

  private

  def enter!
    if @entered
      raise 'Sidekiq::Postpone#wrap is not re-enterable on the same instance'
    else
      @entered = true
    end
    Thread.current[:sidekiq_postpone_stack] ||= []
    Thread.current[:sidekiq_postpone_stack].push(self)
    Thread.current[:sidekiq_postpone] = self
  end

  def leave!
    Thread.current[:sidekiq_postpone_stack].pop
    head = Thread.current[:sidekiq_postpone_stack].last
    Thread.current[:sidekiq_postpone] = head
    @entered = false
    if @flush_on_leave
      @flush_on_leave = false
      flush!
    end
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
