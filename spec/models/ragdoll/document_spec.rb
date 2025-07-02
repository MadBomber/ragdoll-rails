require 'rails_helper'

RSpec.describe Ragdoll::Document, type: :model do
  describe 'associations' do
    it { should have_many(:ragdoll_embeddings).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:location) }
    it { should validate_uniqueness_of(:location) }
  end

  describe 'scopes and queries' do
    let!(:pending_doc) { create(:ragdoll_document, status: 'pending') }
    let!(:completed_doc) { create(:ragdoll_document, :completed) }
    let!(:failed_doc) { create(:ragdoll_document, :failed) }

    it 'filters by status' do
      expect(Ragdoll::Document.where(status: 'completed')).to contain_exactly(completed_doc)
      expect(Ragdoll::Document.where(status: 'pending')).to contain_exactly(pending_doc)
      expect(Ragdoll::Document.where(status: 'failed')).to contain_exactly(failed_doc)
    end

    it 'filters by document type' do
      pdf_doc = create(:ragdoll_document, :pdf)
      text_doc = create(:ragdoll_document, document_type: 'text')
      
      expect(Ragdoll::Document.where(document_type: 'pdf')).to contain_exactly(pdf_doc)
      expect(Ragdoll::Document.where(document_type: 'text')).to include(text_doc)
    end
  end

  describe 'attributes and defaults' do
    subject { build(:ragdoll_document) }

    it 'has default metadata as empty hash' do
      document = Ragdoll::Document.new
      expect(document.metadata).to eq({})
    end

    it 'has default status as pending' do
      document = Ragdoll::Document.new
      expect(document.status).to eq('pending')
    end

    it 'accepts metadata as JSONB' do
      metadata = { author: 'Test Author', version: '1.0' }
      document = create(:ragdoll_document, metadata: metadata)
      
      expect(document.reload.metadata).to eq(metadata.stringify_keys)
    end
  end

  describe 'content handling' do
    it 'stores large content' do
      large_content = 'Large content ' * 10000 # ~130KB
      document = create(:ragdoll_document, content: large_content)
      
      expect(document.reload.content).to eq(large_content)
    end

    it 'handles unicode content' do
      unicode_content = "Test with émojis 🚀 and spëcial chãracters"
      document = create(:ragdoll_document, content: unicode_content)
      
      expect(document.reload.content).to eq(unicode_content)
    end
  end

  describe 'processing timestamps' do
    let(:document) { create(:ragdoll_document) }

    it 'tracks processing start time' do
      time = Time.current
      document.update!(processing_started_at: time)
      
      expect(document.processing_started_at).to be_within(1.second).of(time)
    end

    it 'tracks processing completion' do
      start_time = 1.hour.ago
      end_time = Time.current
      
      document.update!(
        processing_started_at: start_time,
        processing_finished_at: end_time
      )
      
      expect(document.processing_started_at).to be_within(1.second).of(start_time)
      expect(document.processing_finished_at).to be_within(1.second).of(end_time)
    end
  end

  describe 'chunking configuration' do
    it 'has default chunk size and overlap' do
      document = create(:ragdoll_document)
      
      expect(document.chunk_size).to eq(1000)
      expect(document.chunk_overlap).to eq(200)
    end

    it 'allows custom chunk settings' do
      document = create(:ragdoll_document, chunk_size: 1500, chunk_overlap: 300)
      
      expect(document.chunk_size).to eq(1500)
      expect(document.chunk_overlap).to eq(300)
    end
  end

  describe 'embeddings relationship' do
    let(:document) { create(:ragdoll_document, :with_embeddings) }

    it 'destroys embeddings when document is destroyed' do
      embedding_ids = document.ragdoll_embeddings.pluck(:id)
      
      expect { document.destroy }
        .to change { Ragdoll::Embedding.where(id: embedding_ids).count }
        .from(3).to(0)
    end

    it 'can count embeddings' do
      expect(document.ragdoll_embeddings.count).to eq(3)
    end
  end

  describe 'search functionality' do
    let!(:doc1) { create(:ragdoll_document, title: 'Rails Guide', content: 'Ruby on Rails framework') }
    let!(:doc2) { create(:ragdoll_document, title: 'Python Tutorial', content: 'Django web framework') }

    it 'finds documents by title' do
      results = Ragdoll::Document.where("title ILIKE ?", "%Rails%")
      expect(results).to contain_exactly(doc1)
    end

    it 'finds documents by content' do
      results = Ragdoll::Document.where("content ILIKE ?", "%framework%")
      expect(results).to contain_exactly(doc1, doc2)
    end
  end

  describe 'status transitions' do
    let(:document) { create(:ragdoll_document, status: 'pending') }

    it 'can transition to processing' do
      document.update!(status: 'processing', processing_started_at: Time.current)
      
      expect(document.status).to eq('processing')
      expect(document.processing_started_at).to be_present
    end

    it 'can transition to completed' do
      document.update!(
        status: 'completed',
        processing_started_at: 1.hour.ago,
        processing_finished_at: Time.current
      )
      
      expect(document.status).to eq('completed')
      expect(document.processing_finished_at).to be_present
    end

    it 'can transition to failed' do
      document.update!(
        status: 'failed',
        processing_started_at: 1.hour.ago,
        processing_finished_at: Time.current
      )
      
      expect(document.status).to eq('failed')
      expect(document.processing_finished_at).to be_present
    end
  end

  describe 'summary functionality' do
    describe '#has_summary?' do
      it 'returns true when document has summary' do
        document = create(:ragdoll_document, :with_summary)
        expect(document.has_summary?).to be true
      end

      it 'returns false when document has no summary' do
        document = create(:ragdoll_document, summary: nil)
        expect(document.has_summary?).to be false
      end

      it 'returns false when summary is blank' do
        document = create(:ragdoll_document, summary: '')
        expect(document.has_summary?).to be false
      end
    end

    describe '#summary_stale?' do
      it 'returns false when document has no summary' do
        document = create(:ragdoll_document, summary: nil)
        expect(document.summary_stale?).to be false
      end

      it 'returns true when summary_generated_at is nil' do
        document = create(:ragdoll_document, summary: 'test', summary_generated_at: nil)
        expect(document.summary_stale?).to be true
      end

      it 'returns true when document was updated after summary generation' do
        document = create(:ragdoll_document, :stale_summary)
        expect(document.summary_stale?).to be true
      end

      it 'returns false when summary is current' do
        document = create(:ragdoll_document, :with_summary)
        document.update_column(:updated_at, document.summary_generated_at - 1.hour)
        expect(document.summary_stale?).to be false
      end
    end

    describe '#needs_summary?' do
      it 'returns false when document has no content' do
        document = create(:ragdoll_document, content: nil)
        expect(document.needs_summary?).to be false
      end

      it 'returns false when content is too short' do
        short_content = 'a' * 100
        document = create(:ragdoll_document, content: short_content)
        expect(document.needs_summary?).to be false
      end

      it 'returns true when document has sufficient content but no summary' do
        document = create(:ragdoll_document, :needs_summary)
        expect(document.needs_summary?).to be true
      end

      it 'returns true when summary is stale' do
        document = create(:ragdoll_document, :stale_summary)
        expect(document.needs_summary?).to be true
      end

      it 'returns false when document has current summary' do
        document = create(:ragdoll_document, :with_summary)
        document.update_column(:updated_at, document.summary_generated_at - 1.hour)
        expect(document.needs_summary?).to be false
      end
    end

    describe '#summary_word_count' do
      it 'returns 0 for documents without summary' do
        document = create(:ragdoll_document, summary: nil)
        expect(document.summary_word_count).to eq(0)
      end

      it 'counts words in summary' do
        summary = 'This is a test summary with ten words total'
        document = create(:ragdoll_document, summary: summary)
        expect(document.summary_word_count).to eq(10)
      end
    end

    describe '#regenerate_summary!' do
      let(:document) { create(:ragdoll_document, content: 'Content ' * 100) }
      let(:mock_service) { instance_double(Ragdoll::SummarizationService) }

      before do
        allow(Ragdoll::SummarizationService).to receive(:new).and_return(mock_service)
      end

      it 'regenerates summary successfully' do
        new_summary = 'New generated summary'
        allow(mock_service).to receive(:generate_document_summary).and_return(new_summary)

        result = document.regenerate_summary!

        expect(result).to be true
        expect(document.reload.summary).to eq(new_summary)
        expect(document.summary_generated_at).to be_within(1.second).of(Time.current)
        expect(document.summary_model).to eq('gpt-4')
      end

      it 'returns false when summary generation fails' do
        allow(mock_service).to receive(:generate_document_summary).and_return(nil)

        result = document.regenerate_summary!

        expect(result).to be false
        expect(document.reload.summary).to be_nil
      end

      it 'returns false for documents without content' do
        document.update!(content: nil)

        result = document.regenerate_summary!

        expect(result).to be false
        expect(mock_service).not_to have_received(:generate_document_summary)
      end
    end
  end

  describe 'status helper methods' do
    it 'provides status check methods' do
      completed_doc = create(:ragdoll_document, :completed)
      failed_doc = create(:ragdoll_document, :failed)
      processing_doc = create(:ragdoll_document, :processing)
      pending_doc = create(:ragdoll_document, status: 'pending')

      expect(completed_doc.completed?).to be true
      expect(completed_doc.failed?).to be false
      expect(completed_doc.processing?).to be false
      expect(completed_doc.pending?).to be false

      expect(failed_doc.failed?).to be true
      expect(processing_doc.processing?).to be true
      expect(pending_doc.pending?).to be true
    end
  end

  describe 'content helper methods' do
    let(:document) { create(:ragdoll_document, content: 'This is test content with several words.') }

    describe '#word_count' do
      it 'counts words in content' do
        expect(document.word_count).to eq(8)
      end

      it 'returns 0 for documents without content' do
        document.update!(content: nil)
        expect(document.word_count).to eq(0)
      end
    end

    describe '#character_count' do
      it 'counts characters in content' do
        expect(document.character_count).to eq(document.content.length)
      end

      it 'returns 0 for documents without content' do
        document.update!(content: nil)
        expect(document.character_count).to eq(0)
      end
    end

    describe '#processing_duration' do
      it 'calculates processing duration' do
        start_time = 2.hours.ago
        end_time = 1.hour.ago
        document.update!(
          processing_started_at: start_time,
          processing_finished_at: end_time
        )

        duration = document.processing_duration
        expect(duration).to be_within(1.second).of(1.hour)
      end

      it 'returns nil when processing times are missing' do
        expect(document.processing_duration).to be_nil
      end
    end
  end

  describe 'scope methods' do
    let!(:doc_with_summary) { create(:ragdoll_document, :with_summary) }
    let!(:doc_needs_summary) { create(:ragdoll_document, :needs_summary, status: 'completed') }
    let!(:completed_doc) { create(:ragdoll_document, :completed) }

    describe '.with_summaries' do
      it 'returns documents that have summaries' do
        expect(described_class.with_summaries).to contain_exactly(doc_with_summary)
      end
    end

    describe '.needs_summary' do
      it 'returns completed documents without summaries' do
        expect(described_class.needs_summary).to contain_exactly(doc_needs_summary)
      end
    end

    describe '.by_type' do
      it 'filters documents by type' do
        pdf_doc = create(:ragdoll_document, :pdf)
        expect(described_class.by_type('pdf')).to contain_exactly(pdf_doc)
      end
    end
  end

  describe 'search data' do
    let(:document) do
      create(:ragdoll_document,
        title: 'Test Document',
        summary: 'Document summary',
        content: 'Document content',
        metadata: { 'name' => 'metadata name', 'summary' => 'metadata summary' }
      )
    end

    it 'includes all searchable fields' do
      search_data = document.search_data

      expect(search_data).to include(
        title: 'Test Document',
        summary: 'Document summary',
        content: 'Document content',
        metadata_name: 'metadata name',
        metadata_summary: 'metadata summary',
        document_type: document.document_type,
        status: document.status
      )
    end
  end
end
