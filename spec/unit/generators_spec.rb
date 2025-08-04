require 'spec_helper'

RSpec.describe 'Ragdoll Rails Generators' do
  describe 'generator structure' do
    it 'has the init generator file' do
      generator_path = File.expand_path('../../../lib/generators/ragdoll/init/init_generator.rb', __FILE__)
      expect(File.exist?(generator_path)).to be true
    end
    
    it 'has generator templates' do
      templates_path = File.expand_path('../../../lib/generators/ragdoll/init/templates', __FILE__)
      expect(Dir.exist?(templates_path)).to be true
      
      ragdoll_config_template = File.join(templates_path, 'ragdoll_config.rb')
      expect(File.exist?(ragdoll_config_template)).to be true
      
      install_template = File.join(templates_path, 'INSTALL')
      expect(File.exist?(install_template)).to be true
    end
  end

  describe 'generator template content' do
    it 'has a valid ragdoll config template' do
      template_path = File.expand_path('../../../lib/generators/ragdoll/init/templates/ragdoll_config.rb', __FILE__)
      content = File.read(template_path)
      
      expect(content).to include('Ragdoll.configure')
      expect(content).to include('Ragdoll::Rails.configure')
    end
    
    it 'has installation instructions' do
      install_path = File.expand_path('../../../lib/generators/ragdoll/init/templates/INSTALL', __FILE__)
      content = File.read(install_path)
      
      expect(content).to include('Ragdoll Configuration')
      expect(content.length).to be > 100 # Should have substantial content
    end
  end
end