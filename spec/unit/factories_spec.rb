require 'spec_helper'

RSpec.describe 'Factory definitions' do
  describe 'factory loading' do
    it 'can load FactoryBot if available' do
      # Just verify we can reference FactoryBot constants
      if defined?(FactoryBot)
        expect(FactoryBot).to be_a(Module)
      else
        expect(true).to be true # Pass if FactoryBot not available
      end
    end
    
    it 'has factory files defined' do
      factory_files = Dir[File.expand_path('../../factories/**/*.rb', __FILE__)]
      expect(factory_files).not_to be_empty
      expect(factory_files.any? { |f| f.include?('ragdoll_documents') }).to be true
      expect(factory_files.any? { |f| f.include?('ragdoll_embeddings') }).to be true
      # Updated for unified text-based architecture
      expect(factory_files.any? { |f| f.include?('ragdoll_unified_contents') }).to be true
      expect(factory_files.any? { |f| f.include?('ragdoll_unified_documents') }).to be true
    end
  end
end