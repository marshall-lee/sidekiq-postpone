require 'spec_helper'
require 'sidekiq/testing'

describe Sidekiq::Postpone do
  let(:client_args) { nil }
  let(:postponer) { described_class.new(client_args) }

  before do
    sidekiq_worker(:Foo)

    sidekiq_worker(:Bar) do
      sidekiq_options queue: :bar
    end

    sidekiq_worker(:Baz) do
      sidekiq_options queue: :baz
    end
  end

  describe 'integration with Sidekiq::Worker#jobs' do
    before { Sidekiq::Worker.clear_all }

    context 'when inside a #wrap block' do
      it 'leaves the job list untouched' do
        postponer.wrap do
          Foo.perform_async
          expect(Foo.jobs.count).to eq 0
        end
      end
    end

    context 'when outside of #wrap block' do
      it 'adds a job to the list ' do
        expect {
          postponer.wrap do
            Foo.perform_async
          end
        }.to change { Foo.jobs.count }.by 1
      end
    end
  end

  describe 'integration with Sidekiq::Queues' do
    before do
      skip "Sidekiq #{Sidekiq::VERSION} lacks this feature" if Sidekiq::VERSION < '4.0.0'
    end

    let(:queue_foo) { Sidekiq::Queues['default'] }
    let(:queue_bar) { Sidekiq::Queues['bar'] }
    let(:queue_baz) { Sidekiq::Queues['baz'] }

    before { Sidekiq::Queues.clear_all }

    describe 'inside a #wrap block' do
      it 'does not push a job' do
        postponer.wrap do
          Foo.perform_async
          expect(queue_foo.size).to eq 0
        end
      end
    end

    describe 'outside of #wrap block' do
      it 'pushes a job to the queue' do
        expect {
          postponer.wrap do
            Foo.perform_async
          end
        }.to change { queue_foo.size }.by 1
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
    end
  end

  describe 'integration with Sidekiq::Testing.inline!' do
    around { |ex| Sidekiq::Testing.inline!(&ex) }
    let(:side_effect) { { foo: 0 } }

    before do
      eff = side_effect
      Bar.class_eval do
        define_method :perform do
          eff[:foo] += 1
        end
      end
      Foo.class_eval do
        define_method :perform do
          Sidekiq::Postpone.wrap do
            2.times { Bar.perform_async }
          end
        end
      end
    end

    it 'works well' do
      expect { 3.times { Foo.perform_async } }
        .to change { side_effect[:foo] }.by 6
      expect do
        Sidekiq::Postpone.wrap do
          expect { 3.times { Foo.perform_async } }
            .not_to(change { side_effect[:foo] })
        end
      end.to change { side_effect[:foo] }.by 6
    end
  end
end
