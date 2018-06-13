class Sidekiq::Postpone
  module CoreExt
    def raw_push(payloads)
      postpone = Thread.current[:sidekiq_postpone]
      if postpone
        ignored = postpone.push(payloads)
        super(ignored) if ignored
        true
      else
        super
      end
    end
  end

  Sidekiq::Client.prepend CoreExt
end
