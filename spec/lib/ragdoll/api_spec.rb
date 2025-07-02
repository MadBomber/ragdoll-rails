require 'rails_helper'

RSpec.describe Ragdoll::API do
  let(:mock_embedding_service) { instance_double(Ragdoll::EmbeddingService) }
  let(:api) { described_class.new(embedding_service: mock_embedding_service) }
  let(:query_embedding) { Array.new(1536, 0.5) }

  before do
    stub_openai_embeddings
  end

  describe '#initialize' do
    it 'creates default embedding service when none provided' do
      expect(Ragdoll::EmbeddingService).to receive(:new)
      described_class.new
    end

    it 'uses provided embedding service' do
      api = described_class.new(embedding_service: mock_embedding_service)
      expect(api.instance_variable_get(:@embedding_service)).to eq(mock_embedding_service)
    end
  end

  describe '#get_context' do
    let(:prompt) { "How do I configure the database?" }
    let(:mock_search_results) do
      [
        {
          embedding_id: 1,
          document_id: 10,
          document_title: 'Rails Guide',
          content: 'Database configuration content',
          similarity: 0.9,
          chunk_index: 0
        },
        {
          embedding_id: 2,
          document_id: 11,
          document_title: 'Setup Guide',
          content: 'More database info',
          similarity: 0.8,
          chunk_index: 1
        }
      ]
    end

    before do
      allow(mock_embedding_service).to receive(:generate_embedding)
        .with(prompt).and_return(query_embedding)
      allow(api).to receive(:search_similar_content).and_return(mock_search_results)
      allow(api).to receive(:format_context_results).and_call_original
    end

    it 'generates embedding for prompt and searches for similar content' do
      result = api.get_context(prompt)

      expect(mock_embedding_service).to have_received(:generate_embedding).with(prompt)
      expect(api).to have_received(:search_similar_content).with(
        query_embedding,
        limit: 10,
        threshold: 0.7,
        filters: {}
      )
    end

    it 'uses custom limit and threshold' do
      api.get_context(prompt, limit: 5, threshold: 0.8)

      expect(api).to have_received(:search_similar_content).with(
        query_embedding,
        limit: 5,
        threshold: 0.8,
        filters: {}
      )
    end

    it 'formats results for context enhancement' do
      result = api.get_context(prompt)

      expect(result).to include(:prompt, :context_chunks, :total_chunks, :combined_context)
      expect(result[:prompt]).to eq(prompt)
      expect(result[:context_chunks]).to be_an(Array)
      expect(result[:total_chunks]).to eq(2)
      expect(result[:combined_context]).to include('Database configuration content')
    end

    it 'applies filters to search' do
      filters = { document_type: 'pdf' }
      api.get_context(prompt, filters: filters)

      expect(api).to have_received(:search_similar_content).with(
        query_embedding,
        limit: 10,
        threshold: 0.7,
        filters: filters
      )
    end

    it 'raises SearchError for embedding failures' do
      allow(mock_embedding_service).to receive(:generate_embedding)
        .and_raise(Ragdoll::EmbeddingError.new("API Error"))

      expect {
        api.get_context(prompt)
      }.to raise_error(Ragdoll::API::SearchError, /Failed to get context/)
    end
  end

  describe '#search' do
    let(:query) { "Rails configuration" }
    let(:mock_search_results) do
      [
        {
          embedding_id: 1,
          document_id: 10,
          document_title: 'Rails Guide',
          document_location: '/rails_guide.pdf',
          document_type: 'pdf',
          content: 'Rails configuration content',
          similarity: 0.9,
          chunk_index: 0,
          metadata: { source: 'official' }
        }
      ]
    end

    before do
      allow(mock_embedding_service).to receive(:generate_embedding)
        .with(query).and_return(query_embedding)
      allow(api).to receive(:search_similar_content).and_return(mock_search_results)
      allow(api).to receive(:store_search_record)
      allow(api).to receive(:format_search_results).and_call_original
    end

    it 'performs semantic search and stores search record' do
      result = api.search(query)

      expect(mock_embedding_service).to have_received(:generate_embedding).with(query)
      expect(api).to have_received(:search_similar_content)
      expect(api).to have_received(:store_search_record)
      expect(result).to include(:query, :results, :total_results)
    end

    it 'formats search results properly' do
      result = api.search(query)

      expect(result[:query]).to eq(query)
      expect(result[:results]).to be_an(Array)
      expect(result[:results].first).to include(
        :id, :content, :document, :similarity, :chunk_index, :metadata
      )
      expect(result[:total_results]).to eq(1)
    end
  end

  describe '#add_document' do
    context 'with file path' do
      let(:file_path) { '/path/to/document.pdf' }

      before do
        allow(File).to receive(:exist?).with(file_path).and_return(true)
        allow(api).to receive(:add_document_from_file).and_return({ success: true })
      end

      it 'adds document from file path' do
        result = api.add_document(file_path)

        expect(api).to have_received(:add_document_from_file).with(file_path)
        expect(result[:success]).to be true
      end
    end

    context 'with content string' do
      let(:content) { "Document content string" }

      before do
        allow(File).to receive(:exist?).with(content).and_return(false)
        allow(api).to receive(:add_document_from_content).and_return({ id: 123 })
      end

      it 'adds document from content string' do
        result = api.add_document(content, title: 'Test Doc')

        expect(api).to have_received(:add_document_from_content)
          .with(content, title: 'Test Doc')
        expect(result[:id]).to eq(123)
      end
    end

    it 'raises DocumentError for failures' do
      allow(File).to receive(:exist?).and_raise(StandardError.new("File error"))

      expect {
        api.add_document('/bad/path')
      }.to raise_error(Ragdoll::API::DocumentError, /Failed to add document/)
    end
  end

  describe '#update_document' do
    let(:document) { create(:ragdoll_document) }
    let(:updates) { { title: 'New Title', content: 'New content' } }

    before do
      allow(api).to receive(:find_document).with(document.id).and_return(document)
      allow(api).to receive(:reprocess_document)
      allow(api).to receive(:format_document_response).and_call_original
    end

    it 'updates document attributes' do
      expect(document).to receive(:update!).with(title: 'New Title', content: 'New content')

      api.update_document(document.id, updates)
    end

    it 'reprocesses embeddings for content changes' do
      api.update_document(document.id, updates)

      expect(api).to have_received(:reprocess_document).with(document)
    end

    it 'filters allowed updates' do
      invalid_updates = { id: 999, created_at: Time.current, title: 'Valid' }

      expect(document).to receive(:update!).with(title: 'Valid')

      api.update_document(document.id, invalid_updates)
    end

    it 'raises DocumentError for failures' do
      allow(document).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(document))

      expect {
        api.update_document(document.id, updates)
      }.to raise_error(Ragdoll::API::DocumentError, /Failed to update document/)
    end
  end

  describe '#delete_document' do
    let(:document) { create(:ragdoll_document, :with_embeddings) }

    before do
      allow(api).to receive(:find_document).with(document.id).and_return(document)
    end

    it 'deletes document and returns success' do
      embeddings_count = document.ragdoll_embeddings.count
      
      result = api.delete_document(document.id)

      expect(result[:success]).to be true
      expect(result[:embeddings_deleted]).to eq(embeddings_count)
      expect { document.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'raises DocumentError for failures' do
      allow(document).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed.new("Error"))

      expect {
        api.delete_document(document.id)
      }.to raise_error(Ragdoll::API::DocumentError, /Failed to delete document/)
    end
  end

  describe '#get_document' do
    let(:document) { create(:ragdoll_document) }

    before do
      allow(api).to receive(:find_document).with(document.id).and_return(document)
      allow(api).to receive(:format_document_response).and_call_original
    end

    it 'returns formatted document response with content' do
      result = api.get_document(document.id)

      expect(api).to have_received(:format_document_response).with(document, include_content: true)
      expect(result).to include(:id, :title, :content, :status)
    end
  end

  describe '#list_documents' do
    let!(:documents) { create_list(:ragdoll_document, 3, :completed) }

    it 'returns paginated document list' do
      result = api.list_documents(limit: 2, offset: 0)

      expect(result[:documents]).to be_an(Array)
      expect(result[:documents].length).to eq(2)
      expect(result[:pagination]).to include(:total, :limit, :offset, :has_more)
      expect(result[:pagination][:total]).to eq(3)
      expect(result[:pagination][:has_more]).to be true
    end

    it 'applies filters' do
      failed_doc = create(:ragdoll_document, :failed)
      
      result = api.list_documents(filters: { status: 'failed' })

      expect(result[:documents].length).to eq(1)
      expect(result[:documents].first[:id]).to eq(failed_doc.id)
    end

    it 'handles empty results' do
      Ragdoll::Document.destroy_all
      
      result = api.list_documents

      expect(result[:documents]).to be_empty
      expect(result[:pagination][:total]).to eq(0)
      expect(result[:pagination][:has_more]).to be false
    end
  end

  describe '#add_documents_from_directory' do
    let(:directory_path) { '/test/directory' }
    let(:files) { ['/test/directory/file1.txt', '/test/directory/file2.pdf'] }

    before do
      allow(Dir).to receive(:glob).and_return(files)
      allow(File).to receive(:file?).and_return(true)
      allow(Ragdoll::DocumentTypeDetector).to receive(:embeddable?).and_return(true)
      allow(api).to receive(:add_document_from_file).and_return({ id: 123, status: 'success' })
    end

    it 'processes all files in directory' do
      result = api.add_documents_from_directory(directory_path)

      expect(api).to have_received(:add_document_from_file).twice
      expect(result[:total_files]).to eq(2)
      expect(result[:processed]).to eq(2)
      expect(result[:failed]).to eq(0)
    end

    it 'handles recursive directory traversal' do
      api.add_documents_from_directory(directory_path, recursive: true)

      expect(Dir).to have_received(:glob).with("#{directory_path}/**/*")
    end

    it 'skips non-embeddable files' do
      allow(Ragdoll::DocumentTypeDetector).to receive(:embeddable?)
        .and_return(true, false) # First file embeddable, second not

      result = api.add_documents_from_directory(directory_path)

      expect(api).to have_received(:add_document_from_file).once
      expect(result[:processed]).to eq(1)
    end

    it 'handles individual file failures' do
      allow(api).to receive(:add_document_from_file)
        .and_return({ status: 'success' })
        .and_raise(StandardError.new("File error"))

      result = api.add_documents_from_directory(directory_path)

      expect(result[:processed]).to eq(1)
      expect(result[:failed]).to eq(1)
      expect(result[:results].last[:status]).to eq('error')
    end
  end

  describe '#get_search_analytics' do
    before do
      create_list(:ragdoll_search, 3, created_at: 2.days.ago)
      create(:ragdoll_search, query: 'common query', created_at: 1.day.ago)
      create(:ragdoll_search, query: 'common query', created_at: 1.hour.ago)
    end

    it 'returns search analytics for specified period' do
      result = api.get_search_analytics(days: 7)

      expect(result).to include(
        :total_searches, :unique_queries, :average_results,
        :average_search_time, :most_common_queries
      )
      expect(result[:total_searches]).to eq(5)
      expect(result[:most_common_queries].first[:query]).to eq('common query')
      expect(result[:most_common_queries].first[:count]).to eq(2)
    end
  end

  describe '#get_document_stats' do
    before do
      create_list(:ragdoll_document, 2, :completed, :with_embeddings)
      create(:ragdoll_document, :failed)
    end

    it 'returns comprehensive document statistics' do
      result = api.get_document_stats

      expect(result).to include(
        :total_documents, :total_embeddings, :average_embeddings_per_document,
        :documents_by_status, :documents_by_type, :storage_stats
      )
      expect(result[:total_documents]).to eq(3)
      expect(result[:documents_by_status]['completed']).to eq(2)
      expect(result[:documents_by_status]['failed']).to eq(1)
    end
  end

  describe 'private methods' do
    describe '#find_document' do
      let(:document) { create(:ragdoll_document) }

      it 'finds existing document' do
        result = api.send(:find_document, document.id)
        expect(result).to eq(document)
      end

      it 'raises DocumentError for non-existent document' do
        expect {
          api.send(:find_document, 999)
        }.to raise_error(Ragdoll::API::DocumentError, /Document not found/)
      end
    end

    describe '#format_context_results' do
      let(:results) do
        [
          { content: 'Content 1', document_id: 1, document_title: 'Doc 1', chunk_index: 0, similarity: 0.9 },
          { content: 'Content 2', document_id: 2, document_title: 'Doc 2', chunk_index: 1, similarity: 0.8 }
        ]
      end

      it 'formats results for context enhancement' do
        result = api.send(:format_context_results, results, 'test prompt')

        expect(result[:prompt]).to eq('test prompt')
        expect(result[:context_chunks]).to be_an(Array)
        expect(result[:total_chunks]).to eq(2)
        expect(result[:combined_context]).to include('Content 1')
        expect(result[:combined_context]).to include('Content 2')
        expect(result[:combined_context]).to include('---') # Separator
      end
    end

    describe '#format_search_results' do
      let(:results) do
        [
          {
            embedding_id: 1, document_id: 10, document_title: 'Doc',
            document_location: '/doc.pdf', document_type: 'pdf',
            content: 'Content', similarity: 0.9, chunk_index: 0, metadata: {}
          }
        ]
      end

      it 'formats results for search response' do
        result = api.send(:format_search_results, results, 'test query')

        expect(result[:query]).to eq('test query')
        expect(result[:results]).to be_an(Array)
        expect(result[:results].first).to include(
          :id, :content, :document, :similarity, :chunk_index, :metadata
        )
        expect(result[:total_results]).to eq(1)
      end
    end
  end
end