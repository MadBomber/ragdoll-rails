require 'rails_helper'

RSpec.describe 'Ragdoll Integration', type: :integration do
  before do
    # Set up test environment with mocked embedding service
    stub_openai_embeddings
    Ragdoll.instance_variable_set(:@client, nil) # Reset memoized client
  end

  describe 'Full RAG Workflow' do
    it 'performs complete document ingestion and retrieval workflow' do
      # Step 1: Add multiple documents
      doc1_content = "Ruby on Rails is a web application framework written in Ruby. It follows the MVC pattern and emphasizes convention over configuration."
      doc2_content = "PostgreSQL is a powerful, open source object-relational database system. It supports advanced data types and performance optimization."
      doc3_content = "Docker containers provide a lightweight virtualization solution. They package applications with their dependencies for consistent deployment."

      document1 = Ragdoll.add_text(doc1_content, title: "Rails Guide", process_immediately: true)
      document2 = Ragdoll.add_text(doc2_content, title: "PostgreSQL Manual", process_immediately: true)
      document3 = Ragdoll.add_text(doc3_content, title: "Docker Tutorial", process_immediately: true)

      # Verify documents were created
      expect(document1[:id]).to be_present
      expect(document2[:id]).to be_present
      expect(document3[:id]).to be_present

      # Step 2: Verify embeddings were created
      doc1_record = Ragdoll::Document.find(document1[:id])
      doc2_record = Ragdoll::Document.find(document2[:id])
      doc3_record = Ragdoll::Document.find(document3[:id])

      expect(doc1_record.ragdoll_embeddings.count).to be > 0
      expect(doc2_record.ragdoll_embeddings.count).to be > 0
      expect(doc3_record.ragdoll_embeddings.count).to be > 0

      # Step 3: Perform semantic search
      search_results = Ragdoll.search("web framework development")
      expect(search_results[:results]).not_to be_empty
      expect(search_results[:total_results]).to be > 0

      # Rails document should be most relevant for "web framework"
      top_result = search_results[:results].first
      expect(top_result[:document][:title]).to eq("Rails Guide")

      # Step 4: Get context for AI prompt enhancement
      enhanced = Ragdoll.enhance_prompt(
        "How do I build a web application?",
        context_limit: 3,
        threshold: 0.5
      )

      expect(enhanced[:enhanced_prompt]).to include("How do I build a web application?")
      expect(enhanced[:enhanced_prompt]).to include("Ruby on Rails") # Should include Rails context
      expect(enhanced[:context_count]).to be > 0
      expect(enhanced[:context_sources]).not_to be_empty

      # Step 5: Test filtering
      filtered_results = Ragdoll.search(
        "database",
        filters: { document_type: 'text' }
      )

      expect(filtered_results[:results]).not_to be_empty
      # PostgreSQL document should be found
      expect(filtered_results[:results].any? { |r| r[:document][:title] == "PostgreSQL Manual" }).to be true
    end

    it 'handles file-based document ingestion workflow' do
      # Create test files
      rails_file = create_test_text_file(
        "Rails provides rapid development through scaffolding and generators. ActiveRecord handles database interactions.",
        "rails_guide.txt"
      )
      
      docker_file = create_test_markdown_file(
        "# Docker Basics\n\nDocker enables containerization of applications. Use Dockerfile to define container specifications.",
        "docker_guide.md"
      )

      begin
        # Add files to Ragdoll
        result1 = Ragdoll.add_file(rails_file, process_immediately: true)
        result2 = Ragdoll.add_file(docker_file, process_immediately: true)

        expect(result1[:success]).to be true
        expect(result2[:success]).to be true

        # Verify documents were processed
        documents = Ragdoll.client.list_documents(limit: 10)
        expect(documents[:documents].count).to be >= 2

        rails_doc = documents[:documents].find { |d| d[:location] == rails_file }
        docker_doc = documents[:documents].find { |d| d[:location] == docker_file }

        expect(rails_doc).to be_present
        expect(docker_doc).to be_present
        expect(rails_doc[:status]).to eq('completed')
        expect(docker_doc[:status]).to eq('completed')
        expect(docker_doc[:document_type]).to eq('markdown')

        # Test context retrieval for development questions
        context = Ragdoll.client.get_context(
          "How do I containerize a Rails application?",
          limit: 5
        )

        expect(context[:total_chunks]).to be > 0
        expect(context[:combined_context]).to include("Rails") || expect(context[:combined_context]).to include("Docker")

        # Test search across file types
        search_results = Ragdoll.search("application development")
        expect(search_results[:results]).not_to be_empty

      ensure
        cleanup_test_files
      end
    end

    it 'handles document updates and reprocessing' do
      # Create initial document
      original_content = "Basic Rails tutorial covering MVC architecture."
      document = Ragdoll.add_text(original_content, title: "Rails Basics", process_immediately: true)
      
      doc_id = document[:id]
      initial_embeddings_count = Ragdoll::Document.find(doc_id).ragdoll_embeddings.count

      # Update document content
      updated_content = "Advanced Rails tutorial covering MVC architecture, ActiveRecord associations, and deployment strategies."
      update_result = Ragdoll.client.update_document(
        doc_id,
        content: updated_content,
        title: "Advanced Rails Guide"
      )

      expect(update_result[:title]).to eq("Advanced Rails Guide")

      # Verify content was updated and embeddings were reprocessed
      updated_doc = Ragdoll::Document.find(doc_id)
      expect(updated_doc.content).to eq(updated_content)
      expect(updated_doc.title).to eq("Advanced Rails Guide")
      
      # Should have different number of embeddings due to longer content
      final_embeddings_count = updated_doc.ragdoll_embeddings.count
      expect(final_embeddings_count).to be >= initial_embeddings_count

      # Search should now find the updated content
      search_results = Ragdoll.search("deployment strategies")
      expect(search_results[:results]).not_to be_empty
      
      found_doc = search_results[:results].find { |r| r[:document][:id] == doc_id }
      expect(found_doc).to be_present
      expect(found_doc[:content]).to include("deployment strategies")
    end

    it 'handles bulk operations and analytics' do
      # Create multiple documents
      documents_data = [
        { content: "Rails routing and controllers guide", title: "Rails Routing" },
        { content: "ActiveRecord models and migrations", title: "Rails Models" },
        { content: "Rails views and helpers tutorial", title: "Rails Views" },
        { content: "Testing Rails applications with RSpec", title: "Rails Testing" },
        { content: "Deploying Rails to production servers", title: "Rails Deployment" }
      ]

      document_ids = []
      documents_data.each do |doc_data|
        result = Ragdoll.add_text(
          doc_data[:content],
          title: doc_data[:title],
          process_immediately: true
        )
        document_ids << result[:id]
      end

      # Test document statistics
      stats = Ragdoll.stats
      expect(stats[:total_documents]).to be >= 5
      expect(stats[:total_embeddings]).to be > 0
      expect(stats[:documents_by_status]['completed']).to be >= 5

      # Test search analytics (if enabled)
      if Ragdoll.configuration.enable_search_analytics
        # Perform several searches
        ["Rails framework", "testing", "deployment"].each do |query|
          Ragdoll.search(query)
        end

        analytics = Ragdoll.client.search_analytics(days: 1)
        expect(analytics[:total_searches]).to be >= 3
      end

      # Test bulk reprocessing
      reprocess_result = Ragdoll.client.reprocess_all
      expect(reprocess_result[:total_documents]).to be >= 5
      expect(reprocess_result[:processed]).to be >= 5

      # Test document listing with pagination
      page1 = Ragdoll.client.list_documents(limit: 3, offset: 0)
      expect(page1[:documents].count).to eq(3)
      expect(page1[:pagination][:has_more]).to be true

      page2 = Ragdoll.client.list_documents(limit: 3, offset: 3)
      expect(page2[:documents].count).to be >= 2
    end

    it 'handles error scenarios gracefully' do
      # Test with invalid content
      result = Ragdoll.add_text("", title: "Empty Document", process_immediately: true)
      
      # Should create document but with no embeddings
      doc = Ragdoll::Document.find(result[:id])
      expect(doc.ragdoll_embeddings.count).to eq(0)

      # Test search with no matching documents
      search_results = Ragdoll.search("completely unrelated quantum physics terminology")
      expect(search_results[:results]).to be_empty
      expect(search_results[:total_results]).to eq(0)

      # Test context retrieval with no matching content
      context = Ragdoll.client.get_context("unrelated query about astronomy")
      expect(context[:total_chunks]).to eq(0)
      expect(context[:combined_context]).to be_empty

      # Enhanced prompt should fall back to original when no context
      enhanced = Ragdoll.enhance_prompt("astronomy question")
      expect(enhanced[:enhanced_prompt]).to eq("astronomy question")
      expect(enhanced[:context_count]).to eq(0)

      # Test document deletion
      delete_result = Ragdoll.client.delete_document(result[:id])
      expect(delete_result[:success]).to be true

      # Document should be gone
      expect { Ragdoll::Document.find(result[:id]) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'maintains data consistency across operations' do
      # Add document with specific metadata
      document = Ragdoll.add_text(
        "Comprehensive Rails security guide covering authentication, authorization, and data protection.",
        title: "Rails Security",
        metadata: { category: "security", difficulty: "advanced" },
        process_immediately: true
      )

      doc_id = document[:id]
      doc_record = Ragdoll::Document.find(doc_id)

      # Verify metadata preservation
      expect(doc_record.metadata["category"]).to eq("security")
      expect(doc_record.metadata["difficulty"]).to eq("advanced")

      # Verify embeddings reference correct document
      doc_record.ragdoll_embeddings.each do |embedding|
        expect(embedding.document_id).to eq(doc_id)
        expect(embedding.content).to be_present
        expect(embedding.embedding).to be_an(Array)
        expect(embedding.chunk_index).to be >= 0
      end

      # Test search consistency
      search_results = Ragdoll.search("Rails security authentication")
      security_result = search_results[:results].find { |r| r[:document][:id] == doc_id }
      
      expect(security_result).to be_present
      expect(security_result[:document][:title]).to eq("Rails Security")
      expect(security_result[:content]).to include("security")

      # Test update consistency
      updated = Ragdoll.client.update_document(
        doc_id,
        metadata: { category: "security", difficulty: "intermediate", updated: true }
      )

      doc_record.reload
      expect(doc_record.metadata["category"]).to eq("security")
      expect(doc_record.metadata["difficulty"]).to eq("intermediate")
      expect(doc_record.metadata["updated"]).to be true
    end
  end

  describe 'Performance and Scalability' do
    it 'handles moderate document volumes efficiently' do
      start_time = Time.current

      # Create 20 documents of varying sizes
      document_ids = []
      (1..20).each do |i|
        content = "Document #{i} content. " * (50 + i * 10) # Varying content sizes
        result = Ragdoll.add_text(
          content,
          title: "Document #{i}",
          process_immediately: true
        )
        document_ids << result[:id]
      end

      processing_time = Time.current - start_time
      expect(processing_time).to be < 60.seconds # Should complete within reasonable time

      # Verify all documents were processed
      documents = Ragdoll.client.list_documents(limit: 25)
      expect(documents[:documents].count).to eq(20)
      
      completed_docs = documents[:documents].select { |d| d[:status] == 'completed' }
      expect(completed_docs.count).to eq(20)

      # Test search performance
      search_start = Time.current
      results = Ragdoll.search("Document content", limit: 10)
      search_time = Time.current - search_start

      expect(search_time).to be < 5.seconds
      expect(results[:results].count).to be > 0
      expect(results[:results].count).to be <= 10

      # Test context retrieval performance
      context_start = Time.current
      context = Ragdoll.client.get_context("document information", limit: 5)
      context_time = Time.current - context_start

      expect(context_time).to be < 3.seconds
      expect(context[:total_chunks]).to be > 0
      expect(context[:total_chunks]).to be <= 5
    end
  end

  describe 'Multi-format Document Processing' do
    it 'processes different document formats consistently' do
      begin
        # Create documents in different formats
        text_file = create_test_text_file(
          "Plain text document about Rails development and best practices.",
          "guide.txt"
        )
        
        markdown_file = create_test_markdown_file(
          "# Markdown Guide\n\n## Rails Development\n\nThis covers **Rails** development practices.",
          "guide.md"
        )
        
        json_file = create_test_json_file(
          { 
            title: "Rails Configuration",
            content: "JSON document containing Rails configuration examples and settings.",
            tags: ["rails", "config", "json"]
          },
          "config.json"
        )

        # Process all files
        text_result = Ragdoll.add_file(text_file, process_immediately: true)
        markdown_result = Ragdoll.add_file(markdown_file, process_immediately: true)
        json_result = Ragdoll.add_file(json_file, process_immediately: true)

        # Verify all were processed successfully
        [text_result, markdown_result, json_result].each do |result|
          expect(result[:success]).to be true
        end

        # Verify different document types were detected
        documents = Ragdoll.client.list_documents(limit: 10)
        doc_types = documents[:documents].map { |d| d[:document_type] }.uniq
        expect(doc_types).to include('text', 'markdown', 'json')

        # Test cross-format search
        search_results = Ragdoll.search("Rails development")
        expect(search_results[:results].count).to be >= 3

        # Each format should contribute to results
        result_types = search_results[:results].map { |r| r[:document][:type] }.uniq
        expect(result_types.length).to be >= 2

        # Test context enhancement across formats
        enhanced = Ragdoll.enhance_prompt(
          "What are Rails development best practices?",
          context_limit: 5
        )

        expect(enhanced[:context_count]).to be > 0
        expect(enhanced[:enhanced_prompt]).to include("Rails")

      ensure
        cleanup_test_files
      end
    end
  end
end