require 'spec_helper'

describe Sidekiq::Postpone do
  let(:client_args) { nil }
  let(:postponer) { described_class.new(*client_args) }

  before do
    sidekiq_worker(:Foo)

    sidekiq_worker(:Bar) do
      sidekiq_options queue: :bar
    end

    sidekiq_worker(:Baz) do
      sidekiq_options queue: :baz
    end
  end

  def sidekiq_postpone_tls
    Thread.current[:sidekiq_postpone]
  end

  let(:queue_foo) { Sidekiq::Queue.new }
  let(:queue_bar) { Sidekiq::Queue.new('bar') }
  let(:queue_baz) { Sidekiq::Queue.new('baz') }
  let(:scheduled) { Sidekiq::ScheduledSet.new }

  describe '#wrap' do
    it 'returns a value of yield' do
      expect(postponer.wrap { :vova }).to eq(:vova)
    end

    it 'sets a tls variable inside a block' do
      postponer.wrap do
        expect(sidekiq_postpone_tls).to_not be nil
      end
    end

    it 'removes a tls variable outside of a block' do
      postponer.wrap do
        Foo.perform_async
      end
      expect(sidekiq_postpone_tls).to be nil
    end

    it 'removes a tls variable outside of a block even if exception is raised' do
      begin
        postponer.wrap do
          Foo.perform_async
          fail
        end
      rescue
      end
      expect(sidekiq_postpone_tls).to be nil
    end

    context 'with custom client args' do
      let(:client_args) { [:yo, :man] }

      it 'passes these args to Sidekiq::Client' do
        postponer.wrap do
          Foo.perform_async
          expect(Sidekiq::Client).to receive(:new).with(*client_args) { double(raw_push: nil) }
        end
      end
    end

    context 'with perform_async' do
      it 'pushes a job to the queue' do
        expect {
          postponer.wrap do
            Foo.perform_async
          end
        }.to change { queue_foo.size }.by 1
      end

      it 'pushes multiple jobs to the queue' do
        expect {
          postponer.wrap do
            Foo.perform_async
            Foo.perform_async
          end
        }.to change { queue_foo.size }.by 2
      end

      it 'pushes jobs to specified queues' do
        postponer.wrap do
          Foo.perform_async
          Bar.perform_async
          Foo.perform_async
          Bar.perform_async
          Foo.perform_async
          Baz.perform_async
          Baz.perform_async
          Foo.perform_async
          Baz.perform_async
        end
        expect(queue_foo.size).to eq 4
        expect(queue_bar.size).to eq 2
        expect(queue_baz.size).to eq 3
      end

      it 'does not push any job until block exits' do
        postponer.wrap do
          Foo.perform_async
          Bar.perform_async
          expect(queue_foo.size).to eq 0
          expect(queue_bar.size).to eq 0
        end
      end

      it 'does not push any job if error is raised' do
        expect {
          begin
            postponer.wrap do
              Foo.perform_async
              fail
            end
          rescue
          end
        }.not_to change { queue_foo.size }
      end
    end

    context 'with perform_in' do
      let(:at) { Time.now + 1 }

      it 'pushes a job to the scheduled set' do
        expect {
          postponer.wrap do
            Foo.perform_in(at)
          end
        }.to change { scheduled.size }.by 1
      end

      it 'pushes multiple jobs to the scheduled set' do
        expect {
          postponer.wrap do
            Foo.perform_in(at + 1)
            Bar.perform_in(at + 2)
            Foo.perform_in(at + 3)
          end
        }.to change { scheduled.size }.by 3
      end
    end
  end

  describe '.wrap' do
    it 'creates a postpone object and calls #wrap on it' do
      postpone_double = double
      expect(Sidekiq::Postpone).to receive(:new) { postpone_double }
      expect(postpone_double).to receive(:wrap)

      Sidekiq::Postpone.wrap { }
    end

    it 'returns a value of a block' do
      expect(Sidekiq::Postpone.wrap { :vova }).to eq :vova
    end
  end

  describe '#clear!' do
    context 'with perform_async' do
      it 'does not pushe a job to the queue' do
        expect {
          Sidekiq::Postpone.wrap do |postponer|
            Foo.perform_async
            postponer.clear!
          end
        }.not_to change { queue_foo.size }
      end
    end

    context 'with perform_in' do
      let(:at) { Time.now + 1 }

      it 'pushes a job to the scheduled set' do
        expect {
          Sidekiq::Postpone.wrap do |postponer|
            Foo.perform_in(at)
            postponer.clear!
          end
        }.not_to change { scheduled.size }
      end
    end
  end
end
