require 'rails_helper'

RSpec.describe Ragdoll::Ingestion do
  let(:document) { "This is a test document.\n\nIt has multiple paragraphs." }
  let(:ingestion) { described_class.new(document) }

  describe '#chunk_and_vectorize' do
    it 'splits the document into chunks and vectorizes them' do
      result = ingestion.chunk_and_vectorize
      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
    end
  end
end
