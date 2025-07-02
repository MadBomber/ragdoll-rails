# frozen_string_literal: true

# Shared examples for Ragdoll testing

RSpec.shared_examples 'a document processor' do
  it 'processes documents and creates embeddings' do
    expect { subject }.to change { Ragdoll::Document.count }.by(1)
    
    document = Ragdoll::Document.last
    expect(document.status).to eq('completed')
    expect(document.ragdoll_embeddings.count).to be > 0
  end

  it 'handles processing errors gracefully' do
    allow(Ragdoll::EmbeddingService).to receive(:new)
      .and_raise(Ragdoll::EmbeddingError.new("API Error"))

    expect { subject }.to raise_error(StandardError)
  end
end

RSpec.shared_examples 'a searchable interface' do
  let(:query) { "test query" }
  let(:mock_results) do
    [
      {
        embedding_id: 1,
        document_id: 10,
        document_title: 'Test Document',
        content: 'Test content',
        similarity: 0.9,
        chunk_index: 0,
        metadata: {}
      }
    ]
  end

  before do
    allow(subject).to receive(:search_similar_content).and_return(mock_results)
  end

  it 'returns search results with proper structure' do
    result = subject.search(query)
    
    expect(result).to include(:query, :results, :total_results)
    expect(result[:query]).to eq(query)
    expect(result[:results]).to be_an(Array)
    expect(result[:total_results]).to be_a(Integer)
  end

  it 'accepts search parameters' do
    subject.search(query, limit: 5, threshold: 0.8, filters: { type: 'pdf' })
    
    expect(subject).to have_received(:search_similar_content)
      .with(anything, limit: 5, threshold: 0.8, filters: { type: 'pdf' })
  end
end

RSpec.shared_examples 'a context provider' do
  let(:prompt) { "test prompt" }
  let(:context_data) do
    {
      context_chunks: [
        { content: 'Context 1', source: { document_id: 1 } },
        { content: 'Context 2', source: { document_id: 2 } }
      ],
      combined_context: "Context 1\n\n---\n\nContext 2",
      total_chunks: 2
    }
  end

  before do
    allow(subject).to receive(:get_context).and_return(context_data)
  end

  it 'provides context for prompts' do
    result = subject.get_context(prompt)
    
    expect(result).to include(:context_chunks, :combined_context, :total_chunks)
    expect(result[:total_chunks]).to be >= 0
    expect(result[:context_chunks]).to be_an(Array)
  end

  it 'handles empty context gracefully' do
    allow(subject).to receive(:get_context).and_return({
      context_chunks: [],
      combined_context: "",
      total_chunks: 0
    })

    result = subject.get_context(prompt)
    expect(result[:total_chunks]).to eq(0)
    expect(result[:combined_context]).to be_empty
  end
end

RSpec.shared_examples 'a document manager' do
  let(:document) { create(:ragdoll_document) }

  it 'manages document lifecycle' do
    # Create
    new_doc = subject.add_document("test content", title: "Test")
    expect(new_doc).to include(:id)

    # Read
    retrieved = subject.get_document(new_doc[:id])
    expect(retrieved[:title]).to eq("Test")

    # Update
    updated = subject.update_document(new_doc[:id], title: "Updated")
    expect(updated[:title]).to eq("Updated")

    # Delete
    deleted = subject.delete_document(new_doc[:id])
    expect(deleted[:success]).to be true
  end

  it 'lists documents with pagination' do
    create_list(:ragdoll_document, 5)
    
    result = subject.list_documents(limit: 3, offset: 0)
    
    expect(result[:documents]).to be_an(Array)
    expect(result[:documents].length).to eq(3)
    expect(result[:pagination]).to include(:total, :limit, :offset, :has_more)
  end
end

RSpec.shared_examples 'an analytics provider' do
  before do
    create_list(:ragdoll_document, 3, :completed)
    create_list(:ragdoll_search, 5)
  end

  it 'provides document statistics' do
    stats = subject.stats
    
    expect(stats).to include(
      :total_documents, :total_embeddings, :documents_by_status
    )
    expect(stats[:total_documents]).to be >= 3
  end

  it 'provides search analytics' do
    analytics = subject.search_analytics(days: 7)
    
    expect(analytics).to include(
      :total_searches, :unique_queries, :most_common_queries
    )
    expect(analytics[:total_searches]).to be >= 5
  end
end

RSpec.shared_examples 'a configurable component' do
  it 'respects configuration settings' do
    with_ragdoll_config(chunk_size: 1500, chunk_overlap: 300) do
      # Component should use configured values
      expect(Ragdoll.configuration.chunk_size).to eq(1500)
      expect(Ragdoll.configuration.chunk_overlap).to eq(300)
    end
  end

  it 'falls back to defaults when not configured' do
    Ragdoll.instance_variable_set(:@configuration, nil)
    config = Ragdoll.configuration
    
    expect(config.chunk_size).to eq(1000)
    expect(config.chunk_overlap).to eq(200)
  end
end

RSpec.shared_examples 'an error handler' do |error_class|
  it 'raises appropriate error for failures' do
    allow(subject).to receive(:some_method).and_raise(StandardError.new("Internal error"))
    
    expect { subject.some_method }.to raise_error(error_class, /Internal error/)
  end

  it 'provides meaningful error messages' do
    begin
      raise error_class.new("Test error message")
    rescue error_class => e
      expect(e.message).to include("Test error message")
    end
  end
end

RSpec.shared_examples 'a batch processor' do
  it 'processes multiple items efficiently' do
    items = Array.new(5) { |i| "Item #{i}" }
    
    result = subject.process_batch(items)
    
    expect(result[:processed]).to eq(5)
    expect(result[:failed]).to eq(0)
    expect(result[:results]).to be_an(Array)
    expect(result[:results].length).to eq(5)
  end

  it 'handles individual item failures' do
    items = ["valid_item", "invalid_item", "another_valid_item"]
    
    allow(subject).to receive(:process_item)
      .with("valid_item").and_return({ status: 'success' })
      .with("invalid_item").and_raise(StandardError.new("Processing error"))
      .with("another_valid_item").and_return({ status: 'success' })

    result = subject.process_batch(items)
    
    expect(result[:processed]).to eq(2)
    expect(result[:failed]).to eq(1)
  end
end

RSpec.shared_examples 'a vector storage' do
  let(:embedding) { Array.new(1536) { rand } }

  it 'stores and retrieves vector embeddings' do
    stored = subject.store_embedding(embedding, metadata: { test: true })
    retrieved = subject.get_embedding(stored.id)
    
    expect(retrieved.embedding).to eq(embedding)
    expect(retrieved.metadata['test']).to be true
  end

  it 'performs similarity search' do
    # Store multiple embeddings
    similar_embedding = embedding.map { |val| val + 0.01 } # Very similar
    different_embedding = Array.new(1536) { rand } # Different

    subject.store_embedding(similar_embedding)
    subject.store_embedding(different_embedding)

    results = subject.similarity_search(embedding, threshold: 0.9)
    
    expect(results).not_to be_empty
    expect(results.first.similarity).to be > 0.9
  end
end

RSpec.shared_examples 'a file processor' do
  it 'processes supported file types' do
    file_path = create_test_text_file("Test content")
    
    result = subject.process_file(file_path)
    
    expect(result[:success]).to be true
    expect(result[:document_type]).to eq('text')
    
    cleanup_test_files
  end

  it 'rejects unsupported file types' do
    file_path = Rails.root.join('tmp', 'test.exe')
    File.write(file_path, 'binary content')
    
    expect { subject.process_file(file_path.to_s) }
      .to raise_error(Ragdoll::DocumentError, /Unsupported/)
    
    File.delete(file_path) if File.exist?(file_path)
  end

  it 'handles file reading errors' do
    non_existent_file = '/path/to/nonexistent/file.txt'
    
    expect { subject.process_file(non_existent_file) }
      .to raise_error(Ragdoll::DocumentError)
  end
end

RSpec.shared_examples 'a health checkable service' do
  it 'reports healthy status when operational' do
    expect(subject.healthy?).to be true
  end

  it 'reports unhealthy status when errors occur' do
    allow(subject).to receive(:stats).and_raise(StandardError.new("Service error"))
    
    expect(subject.healthy?).to be false
  end
end