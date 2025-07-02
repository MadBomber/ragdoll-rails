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
end
