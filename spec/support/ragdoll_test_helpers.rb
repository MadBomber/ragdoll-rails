# frozen_string_literal: true

module RagdollTestHelpers
  # Mock embedding service for testing
  class MockEmbeddingService
    def generate_embedding(text)
      # Generate a consistent mock embedding based on text content
      text_hash = text.to_s.sum
      Array.new(1536) { |i| (text_hash + i) / 1000000.0 }
    end

    def generate_embeddings_batch(texts)
      texts.map { |text| generate_embedding(text) }
    end

    def cosine_similarity(embedding1, embedding2)
      return 0.0 if embedding1.nil? || embedding2.nil?
      return 1.0 if embedding1 == embedding2
      0.8 # Mock similarity
    end
  end

  # Create test files
  def create_test_text_file(content = "Test document content", filename = "test.txt")
    file_path = Rails.root.join('tmp', filename)
    File.write(file_path, content)
    file_path.to_s
  end

  def create_test_markdown_file(content = "# Test Document\n\nThis is a test.", filename = "test.md")
    file_path = Rails.root.join('tmp', filename)
    File.write(file_path, content)
    file_path.to_s
  end

  def create_test_json_file(data = { "title" => "Test", "content" => "JSON content" }, filename = "test.json")
    file_path = Rails.root.join('tmp', filename)
    File.write(file_path, data.to_json)
    file_path.to_s
  end

  # Cleanup test files
  def cleanup_test_files
    Dir.glob(Rails.root.join('tmp', 'test*')).each { |f| File.delete(f) if File.exist?(f) }
  end

  # Mock RubyLLM API calls
  def mock_ruby_llm_embedding_response(text)
    {
      'data' => [
        {
          'embedding' => Array.new(1536) { |i| (text.sum + i) / 1000000.0 }
        }
      ]
    }
  end

  def stub_ruby_llm_embeddings
    if defined?(RubyLLM::Client)
      allow_any_instance_of(RubyLLM::Client).to receive(:embed) do |client, params|
        input = params[:input]
        if input.is_a?(Array)
          {
            'data' => input.map.with_index do |text, index|
              {
                'embedding' => Array.new(1536) { |i| (text.sum + index + i) / 1000000.0 }
              }
            end
          }
        else
          mock_ruby_llm_embedding_response(input)
        end
      end
    end
  end

  # Vector similarity testing
  def create_similar_embedding(base_embedding, similarity = 0.9)
    noise_factor = 1.0 - similarity
    base_embedding.map { |val| val + (rand(-noise_factor..noise_factor) * 0.1) }
  end

  # Database helpers
  def create_test_document_with_embeddings(content = "Test content", chunk_count = 3)
    document = create(:ragdoll_document, content: content, status: 'completed')
    
    chunk_count.times do |i|
      chunk_content = "#{content} chunk #{i + 1}"
      embedding = Array.new(1536) { |j| (chunk_content.sum + j) / 1000000.0 }
      
      create(:ragdoll_embedding,
        document: document,
        content: chunk_content,
        embedding: embedding,
        embedding_dimensions: 1536,
        model_name: 'text-embedding-3-small',
        chunk_index: i
      )
    end
    
    document
  end

  # Wait for async jobs in tests
  def wait_for_jobs
    # For testing with ActiveJob::TestAdapter
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    ActiveJob::Base.queue_adapter.performed_jobs.clear
  end

  # Configuration helpers
  def with_ragdoll_config(**options)
    original_config = Ragdoll.configuration.dup
    
    options.each do |key, value|
      Ragdoll.configuration.send("#{key}=", value)
    end
    
    yield
  ensure
    # Restore original configuration
    original_config.instance_variables.each do |var|
      value = original_config.instance_variable_get(var)
      Ragdoll.configuration.instance_variable_set(var, value)
    end
  end

  # Error simulation helpers
  def simulate_ruby_llm_error
    if defined?(RubyLLM::Client)
      allow_any_instance_of(RubyLLM::Client).to receive(:embed)
        .and_raise(RubyLLM::Error.new("API Error"))
    end
  end

  def simulate_openai_error
    simulate_ruby_llm_error
  end
  
  # Alias for backwards compatibility
  alias_method :stub_openai_embeddings, :stub_ruby_llm_embeddings

  def simulate_parse_error
    allow(File).to receive(:read).and_raise(StandardError.new("Parse error"))
  end

  # Test data generators
  def generate_test_documents(count = 5)
    (1..count).map do |i|
      create(:ragdoll_document,
        title: "Test Document #{i}",
        content: "This is test document number #{i} with unique content.",
        document_type: ['text', 'pdf', 'docx'].sample,
        status: 'completed'
      )
    end
  end

  def generate_test_embeddings_for_document(document, chunk_count = 3)
    chunks = document.content.scan(/.{1,100}/)
    
    chunks.first(chunk_count).each_with_index do |chunk, index|
      embedding = Array.new(1536) { |i| (chunk.sum + i) / 1000000.0 }
      
      create(:ragdoll_embedding,
        document: document,
        content: chunk,
        embedding: embedding,
        embedding_dimensions: 1536,
        model_name: 'text-embedding-3-small',
        chunk_index: index
      )
    end
  end
end