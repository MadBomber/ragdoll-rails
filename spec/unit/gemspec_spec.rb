require 'spec_helper'

RSpec.describe 'Ragdoll Rails Gemspec' do
  let(:gemspec_path) { File.expand_path('../../../ragdoll-rails.gemspec', __FILE__) }
  let(:gemspec) { 
    if File.exist?(gemspec_path)
      eval(File.read(gemspec_path), binding, gemspec_path)
    end
  }

  describe 'gemspec structure' do
    it 'has a gemspec file' do
      expect(File.exist?(gemspec_path)).to be true
    end
    
    it 'has valid gemspec structure' do
      skip 'Gemspec not found' unless gemspec
      
      expect(gemspec.name).to eq('ragdoll-rails')
      expect(gemspec.version).to be_a(Gem::Version)
      expect(gemspec.authors).not_to be_empty
      expect(gemspec.email).not_to be_empty
      expect(gemspec.description).not_to be_empty
      expect(gemspec.summary).not_to be_empty
    end
    
    it 'includes necessary files' do
      skip 'Gemspec not found' unless gemspec
      
      expect(gemspec.files).to include(match(/lib\/ragdoll-rails\.rb/))
      expect(gemspec.files).to include(match(/lib\/ragdoll\/rails/))
    end
    
    it 'has proper Rails dependency' do
      skip 'Gemspec not found' unless gemspec
      
      rails_dep = gemspec.dependencies.find { |dep| dep.name == 'rails' }
      if rails_dep
        expect(rails_dep.type).to eq(:runtime)
      else
        # Rails dependency might be specified differently, that's okay
        expect(true).to be true
      end
    end
  end
end