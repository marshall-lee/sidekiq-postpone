class Sidekiq::Postpone
  module CoreExt
    def raw_push(payloads)
      postpone = Thread.current[:sidekiq_postpone]
      if postpone
        postpone.push(payloads)
      else
        super
      end
    end
  end

  Sidekiq::Client.prepend CoreExt
end
