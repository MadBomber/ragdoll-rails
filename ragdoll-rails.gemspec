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

  # Core dependency
  spec.add_dependency "ragdoll-core", "~> 1.0"

  # Rails engine dependency
  spec.add_dependency "rails", "~> 8.0"

  # Database and vector search
  spec.add_dependency "pg", "~> 1.1"
  spec.add_dependency "pgvector", "~> 0.2"

  # Background job processing
  spec.add_dependency "sidekiq", "~> 7.0"

  # Development dependencies
  spec.add_development_dependency "rspec-core", "~> 3.12"
  spec.add_development_dependency "rspec-expectations", "~> 3.12"
  spec.add_development_dependency "rspec-mocks", "~> 3.12"
  spec.add_development_dependency "factory_bot_rails", "~> 6.0"
  spec.add_development_dependency "database_cleaner-active_record", "~> 2.0"
end