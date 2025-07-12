require 'rails_helper'

RSpec.describe Ragdoll::ImportFileJob, type: :job do
  include ActiveJob::TestHelper
  
  let(:job) { described_class.new }

  before do
    stub_openai_embeddings
  end

  describe '#perform' do
    context 'with document ID (existing document)' do
      let(:document) { create(:ragdoll_document, content: "Test document content") }

      it 'processes existing document by ID' do
        expect(job).to receive(:process_existing_document).with(document.id)
        
        job.perform(document.id)
      end

      it 'processes existing document by ID string' do
        expect(job).to receive(:process_existing_document).with(document.id)
        
        job.perform(document.id.to_s)
      end
    end

    context 'with file path' do
      let(:file_path) { create_test_text_file("Test content") }

      after { cleanup_test_files }

      it 'processes file by path' do
        expect(job).to receive(:process_file_path).with(file_path)
        
        job.perform(file_path)
      end
    end

    context 'with error handling' do
      let(:document) { create(:ragdoll_document) }

      it 'logs errors and updates document status for document ID' do
        allow(job).to receive(:process_existing_document)
          .and_raise(StandardError.new("Processing error"))
        
        expect(Rails.logger).to receive(:error).twice
        expect(document).to receive(:update!)
          .with(status: 'failed', processing_finished_at: be_a(Time))
        allow(Ragdoll::Document).to receive(:find_by).with(id: document.id).and_return(document)

        expect { job.perform(document.id) }.to raise_error(StandardError, "Processing error")
      end

      it 're-raises the error after handling' do
        allow(job).to receive(:process_existing_document)
          .and_raise(StandardError.new("Processing error"))
        allow(Ragdoll::Document).to receive(:find_by).and_return(nil)

        expect { job.perform(123) }.to raise_error(StandardError, "Processing error")
      end
    end
  end

  describe 'private methods' do
    describe '#process_existing_document' do
      context 'with document that has content' do
        let(:document) { create(:ragdoll_document, content: "Existing content") }

        before do
          allow(job).to receive(:process_document_content)
        end

        it 'processes document content directly' do
          job.send(:process_existing_document, document.id)

          expect(document.reload.status).to eq('completed')
          expect(document.processing_started_at).to be_present
          expect(document.processing_finished_at).to be_present
          expect(job).to have_received(:process_document_content)
            .with(document, "Existing content", {})
        end

        it 'updates processing timestamps' do
          start_time = Time.current
          
          job.send(:process_existing_document, document.id)
          
          document.reload
          expect(document.processing_started_at).to be >= start_time
          expect(document.processing_finished_at).to be >= document.processing_started_at
        end
      end

      context 'with document that needs file parsing' do
        let(:file_path) { create_test_text_file("File content for parsing") }
        let(:document) { create(:ragdoll_document, location: file_path, content: nil) }

        after { cleanup_test_files }

        before do
          allow(job).to receive(:process_document_content)
        end

        it 'parses file and updates document' do
          job.send(:process_existing_document, document.id)

          document.reload
          expect(document.content).to eq("File content for parsing")
          expect(document.document_type).to eq('text')
          expect(document.status).to eq('completed')
          expect(job).to have_received(:process_document_content)
        end
      end

      context 'with missing file and no content' do
        let(:document) { create(:ragdoll_document, location: '/nonexistent/file.txt', content: nil) }

        it 'raises DocumentError for missing file' do
          expect {
            job.send(:process_existing_document, document.id)
          }.to raise_error(Ragdoll::DocumentError, /File not found/)
        end
      end
    end

    describe '#process_file_path' do
      context 'with valid file' do
        let(:file_path) { create_test_text_file("New file content") }

        after { cleanup_test_files }

        before do
          allow(job).to receive(:process_document_content)
        end

        it 'creates new document and processes it' do
          expect {
            job.send(:process_file_path, file_path)
          }.to change { Ragdoll::Document.count }.by(1)

          document = Ragdoll::Document.last
          expect(document.location).to eq(file_path)
          expect(document.content).to eq("New file content")
          expect(document.status).to eq('completed')
          expect(job).to have_received(:process_document_content)
        end

        it 'uses file metadata for document attributes' do
          job.send(:process_file_path, file_path)

          document = Ragdoll::Document.last
          expect(document.title).to eq(File.basename(file_path))
          expect(document.document_type).to eq('text')
          expect(document.source_type).to eq('file')
          expect(document.chunk_size).to eq(500) # From test config
        end
      end

      context 'with existing document (update)' do
        let(:file_path) { create_test_text_file("Updated content") }
        let!(:existing_doc) { create(:ragdoll_document, :with_embeddings, location: file_path) }

        after { cleanup_test_files }

        before do
          allow(job).to receive(:process_document_content)
        end

        it 'updates existing document instead of creating new one' do
          expect {
            job.send(:process_file_path, file_path)
          }.not_to change { Ragdoll::Document.count }

          existing_doc.reload
          expect(existing_doc.content).to eq("Updated content")
        end

        it 'removes existing embeddings before reprocessing' do
          initial_embedding_count = existing_doc.ragdoll_embeddings.count
          expect(initial_embedding_count).to be > 0

          job.send(:process_file_path, file_path)

          # Should remove embeddings and then process_document_content would create new ones
          expect(job).to have_received(:process_document_content)
        end
      end

      context 'with up-to-date file' do
        let(:file_path) { create_test_text_file("Content") }
        let!(:existing_doc) do
          create(:ragdoll_document, 
            location: file_path, 
            updated_at: 1.hour.from_now # Future timestamp
          )
        end

        after { cleanup_test_files }

        it 'skips processing if file is up-to-date' do
          result = job.send(:process_file_path, file_path)

          expect(result).to eq(existing_doc)
          expect(Rails.logger).to have_received(:info).with(/already up-to-date/)
        end
      end

      context 'with unsupported file types' do
        it 'skips unsupported file extensions' do
          file_path = Rails.root.join('tmp', 'test.exe')
          File.write(file_path, 'binary content')

          result = job.send(:process_file_path, file_path.to_s)

          expect(result).to be_nil
          expect(Rails.logger).to have_received(:warn).with(/Unsupported file type/)

          File.delete(file_path) if File.exist?(file_path)
        end

        it 'skips non-file paths' do
          result = job.send(:process_file_path, '/nonexistent/directory')

          expect(result).to be_nil
        end
      end
    end

    describe '#process_document_content' do
      let(:document) { create(:ragdoll_document, chunk_size: 100, chunk_overlap: 20) }
      let(:content) { "This is test content. " * 10 } # ~200 chars, should create multiple chunks

      before do
        allow(Ragdoll::EmbeddingService).to receive(:new).and_return(MockEmbeddingService.new)
      end

      it 'chunks content and creates embeddings' do
        expect {
          job.send(:process_document_content, document, content)
        }.to change { document.ragdoll_embeddings.count }.from(0).to(be > 1)

        embeddings = document.ragdoll_embeddings
        expect(embeddings.first.content).to include("This is test content")
        expect(embeddings.first.embedding).to be_an(Array)
        expect(embeddings.first.embedding.length).to eq(1536)
        expect(embeddings.first.model_name).to eq('text-embedding-3-small')
      end

      it 'sets chunk metadata and indices' do
        job.send(:process_document_content, document, content)

        embeddings = document.ragdoll_embeddings.order(:chunk_index)
        embeddings.each_with_index do |embedding, index|
          expect(embedding.chunk_index).to eq(index)
          expect(embedding.token_count).to be > 0
          expect(embedding.metadata).to include('chunk_length', 'word_count')
        end
      end

      it 'skips empty content' do
        expect {
          job.send(:process_document_content, document, "")
        }.not_to change { document.ragdoll_embeddings.count }

        expect {
          job.send(:process_document_content, document, nil)
        }.not_to change { document.ragdoll_embeddings.count }
      end

      it 'logs processing completion' do
        job.send(:process_document_content, document, content)

        expect(Rails.logger).to have_received(:info)
          .with(/Created \d+ embeddings for document #{document.id}/)
      end
    end

    describe '#supported_file?' do
      it 'returns true for supported extensions' do
        supported_files = %w[
          /path/file.txt /path/file.md /path/file.pdf
          /path/file.docx /path/file.html /path/file.json
        ]

        supported_files.each do |file_path|
          expect(job.send(:supported_file?, file_path)).to be true
        end
      end

      it 'returns false for unsupported extensions' do
        unsupported_files = %w[
          /path/file.exe /path/file.bin /path/file.mp3
          /path/file.jpg /path/file.unknown
        ]

        unsupported_files.each do |file_path|
          expect(job.send(:supported_file?, file_path)).to be false
          expect(Rails.logger).to have_received(:warn)
            .with(/Unsupported file type/)
        end
      end

      it 'handles files without extensions' do
        expect(job.send(:supported_file?, '/path/README')).to be false
      end
    end
  end

  describe 'integration with ActiveJob' do
    it 'enqueues job with file path' do
      file_path = '/test/file.txt'

      expect {
        described_class.perform_later(file_path)
      }.to have_enqueued_job(described_class).with(file_path)
    end

    it 'enqueues job with document ID' do
      document_id = 123

      expect {
        described_class.perform_later(document_id)
      }.to have_enqueued_job(described_class).with(document_id)
    end

    it 'performs job immediately' do
      file_path = create_test_text_file("Immediate processing")
      
      expect {
        perform_enqueued_jobs do
          described_class.perform_later(file_path)
        end
      }.to change { Ragdoll::Document.count }.by(1)

      cleanup_test_files
    end
  end

  describe 'error scenarios' do
    let(:document) { create(:ragdoll_document, content: "Test content") }

    it 'handles embedding service errors gracefully' do
      allow(Ragdoll::EmbeddingService).to receive(:new)
        .and_raise(Ragdoll::EmbeddingError.new("API error"))

      expect {
        job.perform(document.id)
      }.to raise_error(StandardError)

      document.reload
      expect(document.status).to eq('failed')
      expect(document.processing_finished_at).to be_present
    end

    it 'handles document parsing errors' do
      allow(Ragdoll::DocumentParser).to receive(:parse)
        .and_raise(Ragdoll::DocumentParser::ParseError.new("Parse error"))

      file_path = create_test_text_file("Test")

      expect {
        job.perform(file_path)
      }.to raise_error(StandardError)

      cleanup_test_files
    end

    it 'handles database errors during document creation' do
      allow(Ragdoll::Document).to receive(:new).and_raise(ActiveRecord::RecordInvalid.new(Ragdoll::Document.new))

      file_path = create_test_text_file("Test")

      expect {
        job.perform(file_path)
      }.to raise_error(StandardError)

      cleanup_test_files
    end
  end
end