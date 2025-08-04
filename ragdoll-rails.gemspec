# This file defines the gemspec for the Ragdoll Rails engine gem.

# frozen_string_literal: true

require_relative "lib/ragdoll/rails/version"

Gem::Specification.new do |spec|
  spec.name        = "ragdoll-rails"
  spec.version     = Ragdoll::Rails::VERSION
  spec.authors     = ["Dewayne VanHoozer"]
  spec.email       = ["dvanhoozer@gmail.com"]

  spec.summary     = "Rails engine for Ragdoll RAG system"
  spec.description = "Rails engine providing ActiveRecord integration, background jobs, and UI components for the Ragdoll RAG (Retrieval-Augmented Generation) system"
  spec.homepage    = "https://github.com/MadBomber/ragdoll-rails"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/blob/main"
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir[
    "{app,config,db,lib}/**/*",
    "MIT-LICENSE",
    "Rakefile",
    "README.md"
  ]
  spec.require_paths = ["lib"]
  
  # Core dependencies
  spec.add_dependency "ragdoll", ">= 0.1.0"
  spec.add_dependency "rails", ">= 7.0.0"
end
