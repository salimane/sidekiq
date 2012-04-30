require 'helper'
require 'sidekiq'
require 'active_record'
require 'action_mailer'
require 'mongoid'
require 'sidekiq/extensions/action_mailer'
require 'sidekiq/extensions/active_record'
require 'sidekiq/extensions/mongoid'
require 'sidekiq/rails'

Sidekiq.hook_rails!

class TestExtensions < MiniTest::Unit::TestCase
  describe 'sidekiq extensions' do
    before do
      Sidekiq.redis = REDIS
      Sidekiq.redis {|c| c.flushdb }
    end

    describe 'ActiveRecord' do
      class MyModel < ActiveRecord::Base
        def self.long_class_method
          raise "Should not be called!"
        end
      end

      it 'allows delayed execution of ActiveRecord class methods' do
        assert_equal [], Sidekiq::Client.registered_queues
        assert_equal 0, Sidekiq.redis {|c| c.llen('queue:default') }
        MyModel.delay.long_class_method
        assert_equal ['default'], Sidekiq::Client.registered_queues
        assert_equal 1, Sidekiq.redis {|c| c.llen('queue:default') }
      end
    end

    describe 'Mongoid' do
      class MyDoc
        include Mongoid::Document
        include Sidekiq::Extensions::Mongoid
        def self.long_class_method
          raise "Should not be called!"
        end
      end

      it 'allows delayed exection of Mongoid class methods' do
        assert_equal [], Sidekiq::Client.registered_queues
        assert_equal 0, Sidekiq.redis {|c| c.llen('queue:default') }
        MyDoc.delay.long_class_method
        assert_equal ['default'], Sidekiq::Client.registered_queues
        assert_equal 1, Sidekiq.redis {|c| c.llen('queue:default') }
      end
    end

    describe 'ActionMailer' do
      class UserMailer < ActionMailer::Base
        def greetings(a, b)
          raise "Should not be called!"
        end
      end

      it 'allows delayed delivery of ActionMailer mails' do
        assert_equal [], Sidekiq::Client.registered_queues
        assert_equal 0, Sidekiq.redis {|c| c.llen('queue:default') }
        UserMailer.delay.greetings(1, 2)
        assert_equal ['default'], Sidekiq::Client.registered_queues
        assert_equal 1, Sidekiq.redis {|c| c.llen('queue:default') }
      end
    end
  end

  describe 'sidekiq rails extensions configuration' do
    before do
      @options = Sidekiq.options
    end

    after do
      Sidekiq.options = @options
    end

    it 'should set enable_rails_extensions option to true by default' do
      assert Sidekiq.options[:enable_rails_extensions]
    end

    it 'should extend ActiveRecord and ActiveMailer if enable_rails_extensions is true' do
      assert Sidekiq.hook_rails!
    end

    it 'should not extend ActiveRecord and ActiveMailer if enable_rails_extensions is false' do
      Sidekiq.options = { :enable_rails_extensions => false }
      refute Sidekiq.hook_rails!
    end
  end
end
