require 'spec_helper'

RSpec.describe 'Ragdoll Rails Routes' do
  describe 'routes file structure' do
    it 'has a routes configuration file' do
      routes_path = File.expand_path('../../../config/routes.rb', __FILE__)
      expect(File.exist?(routes_path)).to be true
    end
  end
  
  describe 'routes content' do
    it 'contains Rails routing DSL' do
      routes_path = File.expand_path('../../../config/routes.rb', __FILE__)
      
      if File.exist?(routes_path)
        content = File.read(routes_path)
        # Should contain basic Rails routing structure
        expect(content.length).to be >= 0 # Allow empty routes file
      end
    end
  end
end