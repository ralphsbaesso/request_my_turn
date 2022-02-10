# frozen_string_literal: true

RSpec.describe RequestMyTurn do
  let(:instance) { RequestMyTurn.new(:my_key) }
  let(:url) { 'http://localhost:4567' }

  before { RequestMyTurn.instance_variable_set :@settings, nil }

  it 'has a version number' do
    expect(RequestMyTurn::VERSION).not_to be nil
  end

  context 'class methods' do
    context '.configure' do
      it do
        url = 'https://my_url'
        RequestMyTurn.configure do |config|
          config.url = url
        end

        expect(RequestMyTurn.settings.url).to eq(url)
      end
    end
  end

  context 'instance methods' do
    context '#perform' do
      it 'must throw exception without block' do
        expect { instance.perform }.to raise_error(RequestMyTurn::WithoutBlock)
      end

      it 'request my turn', :vcr do
        returned_id = nil
        returned_seconds = nil

        options = {
          url: 'http://localhost:4567',
          timeout: 20,
          lock_seconds: 10,
          before: ->(service) { returned_id = service.id },
          after: ->(service) { returned_seconds = service.locked }
        }

        instance = RequestMyTurn.new(:my_turn, **options)

        result = instance.perform { 1 + 1 }
        expect(result).to eq(2)
        expect(returned_id).to be_a(String)
        expect(returned_seconds).to end_with('seconds')
      end

      context 'with timeout error' do
        before do
          allow_any_instance_of(RequestMyTurn).to receive(:request).and_raise(Timeout::Error)
        end

        it '@ignore_timeout_error = true' do
          options = {
            url: url,
            timeout: 1,
            ignore_timeout_error: true
          }

          instance = RequestMyTurn.new(:my_turn, **options)
          result = instance.perform { 1 + 1 }
          expect(result).to eq(2)
        end

        it '@ignore_timeout_error = false' do
          timeout = [1, 2, 3].sample
          options = {
            url: url,
            timeout: timeout
          }

          instance = RequestMyTurn.new(:my_turn, **options)
          expect { instance.perform { 1 + 1 } }
            .to raise_error("I didn't get the turn within #{timeout} seconds")
        end
      end
    end

    context '#take_my_turn' do
      it 'must return id', :vcr do
        instance = RequestMyTurn.new(:my_queue, url: url)
        id = instance.send :take_my_turn
        expect(id).to be_a(String)
      end
    end

    context '#switched_on?' do
      it do
        instance = RequestMyTurn.new(:my_queue)
        expect(instance.send(:switched_on?)).to be_truthy

        instance1 = RequestMyTurn.new(:my_queue, switch: false)
        expect(instance1.send(:switched_on?)).to be_falsy

        instance2 = RequestMyTurn.new(:my_queue, switch: proc { true })
        expect(instance2.send(:switched_on?)).to be_truthy

        instance3 = RequestMyTurn.new(:my_queue, switch: proc { false })
        expect(instance3.send(:switched_on?)).to be_falsey
      end

      context 'configured by "RequestMyTurn.settings"' do
        it do
          RequestMyTurn.configure { |config| config.switch = true }
          instance = RequestMyTurn.new(:my_queue)
          expect(instance.send(:switched_on?)).to be_truthy

          RequestMyTurn.configure { |config| config.switch = false }
          instance1 = RequestMyTurn.new(:my_queue)
          expect(instance1.send(:switched_on?)).to be_falsey

          RequestMyTurn.configure { |config| config.switch = proc { true } }
          instance2 = RequestMyTurn.new(:my_queue)
          expect(instance2.send(:switched_on?)).to be_truthy

          RequestMyTurn.configure { |config| config.switch = proc { false } }
          instance3 = RequestMyTurn.new(:my_queue)
          expect(instance3.send(:switched_on?)).to be_falsey

          RequestMyTurn.configure { |config| config.switch = proc { false } }
          instance4 = RequestMyTurn.new(:my_queue, switch: proc { true })
          expect(instance4.send(:switched_on?)).to be_truthy
        end
      end
    end
  end
end
