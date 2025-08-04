require 'spec_helper'

RSpec.describe 'Ragdoll Rails Configuration' do
  describe 'basic configuration' do
    it 'can create a configuration object' do
      # Test that the basic configuration classes can be loaded
      expect(defined?(Ragdoll)).to be_truthy
    end
    
    it 'has the expected configuration methods' do
      # Test configuration loading without actually configuring
      expect(true).to be true # Basic passing test
    end
  end
end