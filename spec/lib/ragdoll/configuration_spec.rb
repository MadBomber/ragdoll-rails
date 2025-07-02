require 'rails_helper'

RSpec.describe Ragdoll::Configuration do
  let(:config) { described_class.new }

  describe '#initialize' do
    it 'sets default values' do
      expect(config.openai_api_key).to eq('test-key') # From test environment
      expect(config.embedding_model).to eq('text-embedding-3-small')
      expect(config.chunk_size).to eq(1000)
      expect(config.chunk_overlap).to eq(200)
      expect(config.search_similarity_threshold).to eq(0.7)
      expect(config.max_search_results).to eq(10)
      expect(config.default_model).to eq('gpt-4')
      expect(config.prompt_template).to be_nil
      expect(config.enable_search_analytics).to be true
      expect(config.cache_embeddings).to be true
    end

    it 'reads OpenAI API key from environment' do
      original_key = ENV['OPENAI_API_KEY']
      ENV['OPENAI_API_KEY'] = 'env-test-key'
      
      new_config = described_class.new
      expect(new_config.openai_api_key).to eq('env-test-key')
      
      ENV['OPENAI_API_KEY'] = original_key
    end
  end

  describe 'attribute accessors' do
    it 'allows reading and writing openai_api_key' do
      config.openai_api_key = 'new-key'
      expect(config.openai_api_key).to eq('new-key')
    end

    it 'allows reading and writing embedding_model' do
      config.embedding_model = 'text-embedding-3-large'
      expect(config.embedding_model).to eq('text-embedding-3-large')
    end

    it 'allows reading and writing chunk_size' do
      config.chunk_size = 1500
      expect(config.chunk_size).to eq(1500)
    end

    it 'allows reading and writing chunk_overlap' do
      config.chunk_overlap = 300
      expect(config.chunk_overlap).to eq(300)
    end

    it 'allows reading and writing search_similarity_threshold' do
      config.search_similarity_threshold = 0.85
      expect(config.search_similarity_threshold).to eq(0.85)
    end

    it 'allows reading and writing max_search_results' do
      config.max_search_results = 20
      expect(config.max_search_results).to eq(20)
    end

    it 'allows reading and writing default_model' do
      config.default_model = 'gpt-3.5-turbo'
      expect(config.default_model).to eq('gpt-3.5-turbo')
    end

    it 'allows reading and writing prompt_template' do
      template = "Custom template with {{context}} and {{prompt}}"
      config.prompt_template = template
      expect(config.prompt_template).to eq(template)
    end

    it 'allows reading and writing enable_search_analytics' do
      config.enable_search_analytics = false
      expect(config.enable_search_analytics).to be false
    end

    it 'allows reading and writing cache_embeddings' do
      config.cache_embeddings = false
      expect(config.cache_embeddings).to be false
    end
  end
end

RSpec.describe Ragdoll do
  describe '.configuration' do
    it 'returns a Configuration instance' do
      expect(Ragdoll.configuration).to be_a(Ragdoll::Configuration)
    end

    it 'memoizes the configuration instance' do
      config1 = Ragdoll.configuration
      config2 = Ragdoll.configuration
      
      expect(config1).to be(config2) # Same object instance
    end

    it 'can be reset for testing' do
      original_config = Ragdoll.configuration
      original_config.chunk_size = 999
      
      # Reset configuration
      Ragdoll.instance_variable_set(:@configuration, nil)
      new_config = Ragdoll.configuration
      
      expect(new_config).not_to be(original_config)
      expect(new_config.chunk_size).to eq(1000) # Default value
    end
  end

  describe '.configure' do
    before do
      # Reset configuration for each test
      Ragdoll.instance_variable_set(:@configuration, nil)
    end

    it 'yields the configuration object for modification' do
      Ragdoll.configure do |config|
        expect(config).to be_a(Ragdoll::Configuration)
        config.chunk_size = 1200
        config.embedding_model = 'text-embedding-3-large'
      end

      expect(Ragdoll.configuration.chunk_size).to eq(1200)
      expect(Ragdoll.configuration.embedding_model).to eq('text-embedding-3-large')
    end

    it 'allows chaining configuration calls' do
      Ragdoll.configure do |config|
        config.chunk_size = 800
      end

      Ragdoll.configure do |config|
        config.chunk_overlap = 150
      end

      expect(Ragdoll.configuration.chunk_size).to eq(800)
      expect(Ragdoll.configuration.chunk_overlap).to eq(150)
    end

    it 'works with complex configuration' do
      custom_template = <<~TEMPLATE
        You are an AI assistant. Use the following context:
        
        {{context}}
        
        Question: {{prompt}}
        
        Please provide a detailed answer:
      TEMPLATE

      Ragdoll.configure do |config|
        config.openai_api_key = 'custom-key-123'
        config.embedding_model = 'text-embedding-3-large'
        config.chunk_size = 1500
        config.chunk_overlap = 300
        config.search_similarity_threshold = 0.8
        config.max_search_results = 15
        config.default_model = 'gpt-4-turbo'
        config.prompt_template = custom_template
        config.enable_search_analytics = false
        config.cache_embeddings = true
      end

      config = Ragdoll.configuration
      expect(config.openai_api_key).to eq('custom-key-123')
      expect(config.embedding_model).to eq('text-embedding-3-large')
      expect(config.chunk_size).to eq(1500)
      expect(config.chunk_overlap).to eq(300)
      expect(config.search_similarity_threshold).to eq(0.8)
      expect(config.max_search_results).to eq(15)
      expect(config.default_model).to eq('gpt-4-turbo')
      expect(config.prompt_template).to eq(custom_template)
      expect(config.enable_search_analytics).to be false
      expect(config.cache_embeddings).to be true
    end
  end

  describe 'configuration validation' do
    before do
      Ragdoll.instance_variable_set(:@configuration, nil)
    end

    it 'accepts valid chunk sizes' do
      Ragdoll.configure do |config|
        config.chunk_size = 500
        config.chunk_overlap = 100
      end

      expect(Ragdoll.configuration.chunk_size).to eq(500)
      expect(Ragdoll.configuration.chunk_overlap).to eq(100)
    end

    it 'accepts valid similarity thresholds' do
      Ragdoll.configure do |config|
        config.search_similarity_threshold = 0.9
      end

      expect(Ragdoll.configuration.search_similarity_threshold).to eq(0.9)
    end

    it 'accepts various embedding models' do
      models = [
        'text-embedding-3-small',
        'text-embedding-3-large',
        'text-embedding-ada-002'
      ]

      models.each do |model|
        Ragdoll.configure do |config|
          config.embedding_model = model
        end

        expect(Ragdoll.configuration.embedding_model).to eq(model)
        
        # Reset for next iteration
        Ragdoll.instance_variable_set(:@configuration, nil)
      end
    end
  end

  describe 'integration with other components' do
    before do
      Ragdoll.instance_variable_set(:@configuration, nil)
    end

    it 'configuration is used by EmbeddingService' do
      Ragdoll.configure do |config|
        config.embedding_model = 'custom-model'
      end

      # Mock the OpenAI client to verify the model is used
      mock_client = double('openai_client')
      allow(OpenAI::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:embeddings).and_return({
        'data' => [{ 'embedding' => [1.0] }]
      })

      service = Ragdoll::EmbeddingService.new
      service.generate_embedding("test")

      expect(mock_client).to have_received(:embeddings).with(
        parameters: {
          model: 'custom-model',
          input: 'test'
        }
      )
    end

    it 'configuration is used by TextChunker defaults' do
      Ragdoll.configure do |config|
        config.chunk_size = 1200
        config.chunk_overlap = 250
      end

      # These would be used as defaults in document processing
      expect(Ragdoll.configuration.chunk_size).to eq(1200)
      expect(Ragdoll.configuration.chunk_overlap).to eq(250)
    end
  end

  describe 'configuration persistence' do
    it 'maintains configuration across multiple accesses' do
      Ragdoll.configure do |config|
        config.chunk_size = 1337
      end

      # Access configuration multiple times
      size1 = Ragdoll.configuration.chunk_size
      size2 = Ragdoll.configuration.chunk_size
      size3 = Ragdoll.configuration.chunk_size

      expect(size1).to eq(1337)
      expect(size2).to eq(1337)
      expect(size3).to eq(1337)
    end

    it 'allows modification after initial configuration' do
      Ragdoll.configure do |config|
        config.chunk_size = 800
      end

      expect(Ragdoll.configuration.chunk_size).to eq(800)

      # Modify directly
      Ragdoll.configuration.chunk_size = 900
      expect(Ragdoll.configuration.chunk_size).to eq(900)

      # Configure again
      Ragdoll.configure do |config|
        config.chunk_size = 1000
      end

      expect(Ragdoll.configuration.chunk_size).to eq(1000)
    end
  end
end