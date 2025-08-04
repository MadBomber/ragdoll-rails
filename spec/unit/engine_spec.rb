require 'spec_helper'

RSpec.describe 'Ragdoll Rails Engine' do
  describe 'engine structure' do
    it 'defines the Ragdoll::Rails module' do
      expect(defined?(Ragdoll::Rails)).to be_truthy
    end
    
    it 'has a configuration class' do
      expect(defined?(Ragdoll::Rails::Configuration)).to be_truthy
    end
    
    it 'has a version constant' do
      expect(defined?(Ragdoll::Rails::VERSION)).to be_truthy
    end
    
    it 'can create a configuration object' do
      config = Ragdoll::Rails::Configuration.new
      expect(config).to be_a(Ragdoll::Rails::Configuration)
    end
  end

  describe 'configuration' do
    let(:config) { Ragdoll::Rails::Configuration.new }

    it 'has default values' do
      expect(config.use_background_jobs).to be true
      expect(config.job_queue).to eq(:default)
      expect(config.job_adapter).to eq(:sidekiq)
      expect(config.queue_name).to eq(:ragdoll)
      expect(config.max_file_size).to eq(10 * 1024 * 1024)
      expect(config.allowed_file_types).to be_an(Array)
      expect(config.allowed_file_types).to include('pdf', 'txt', 'md')
    end

    it 'allows configuration changes' do
      config.use_background_jobs = false
      config.max_file_size = 5 * 1024 * 1024
      config.queue_name = :custom_queue

      expect(config.use_background_jobs).to be false
      expect(config.max_file_size).to eq(5 * 1024 * 1024)
      expect(config.queue_name).to eq(:custom_queue)
    end
  end

  describe 'module methods' do
    it 'provides access to configuration' do
      expect(Ragdoll::Rails).to respond_to(:configuration)
      expect(Ragdoll::Rails.configuration).to be_a(Ragdoll::Rails::Configuration)
    end

    it 'provides a configure method' do
      expect(Ragdoll::Rails).to respond_to(:configure)
    end

    it 'can be configured with a block' do
      original_max_size = Ragdoll::Rails.configuration.max_file_size
      
      Ragdoll::Rails.configure do |config|
        config.max_file_size = 20 * 1024 * 1024
      end

      expect(Ragdoll::Rails.configuration.max_file_size).to eq(20 * 1024 * 1024)
      
      # Reset to original
      Ragdoll::Rails.configuration.max_file_size = original_max_size
    end
  end
end