require 'rails_helper'

RSpec.describe Ragdoll::Search do
  let(:prompt) { "test" }
  let(:search) { described_class.new(prompt) }

  describe '#search_database' do
    it 'returns an array of results' do
      results = search.search_database(10)
      expect(results).to be_an(Array)
    end
  end
end
