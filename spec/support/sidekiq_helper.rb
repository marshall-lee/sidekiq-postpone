module SidekiqHelper
  def sidekiq_worker(name, &block)
    klass = Class.new do
      include Sidekiq::Worker
    end
    Object.const_set(name, klass)
    klass.class_eval(&block) if block
    (@sidekiq_workers ||= []) << klass
    klass
  end

  def clear_sidekiq_workers
    (@sidekiq_workers || []).each do |klass|
      Object.send(:remove_const, klass.name)
    end
  end
end
