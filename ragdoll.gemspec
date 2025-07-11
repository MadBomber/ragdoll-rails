# This file defines the gemspec for the Ragdoll gem, including its dependencies and metadata.

# frozen_string_literal: true

require_relative "lib/ragdoll/version"

Gem::Specification.new do |spec|
  spec.name        = "ragdoll"
  spec.version     = Ragdoll::VERSION
  spec.authors     = ["Dewayne VanHoozer"]
  spec.email       = ["dvanhoozer@gmail.com"]

  spec.summary     = "Retrieval Augmented Generation for Rails"
  spec.description = "Under development.  Contributors welcome."
  spec.homepage    = "https://github.com/MadBomber/ragdoll"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/blob/main"
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been
  # added into git.
  gemspec = File.basename(__FILE__)
  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md", "Thorfile"]
  spec.bindir        = "bin"
  spec.require_paths = ["lib"]

  # Core Rails engine dependency
  spec.add_dependency "rails", "~> 8.0"

  # Vector search and embeddings
  spec.add_dependency "pg", "~> 1.1"
  spec.add_dependency "pgvector", "~> 0.2"

  # HTTP client for API calls
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"

  # Background job processing
  spec.add_dependency "sidekiq", "~> 7.0"

  # Text processing and LLM integration
  spec.add_dependency "ruby_llm", "~> 1.3"

  # Document parsing
  spec.add_dependency "pdf-reader", "~> 2.0"
  spec.add_dependency "docx", "~> 0.8"
  spec.add_dependency "rubyzip", "~> 2.0"

  # Development dependencies
  spec.add_development_dependency "rspec-core", "~> 3.12"
  spec.add_development_dependency "rspec-expectations", "~> 3.12"
  spec.add_development_dependency "rspec-mocks", "~> 3.12"
  spec.add_development_dependency "factory_bot_rails", "~> 6.0"
  spec.add_development_dependency "database_cleaner-active_record", "~> 2.0"
end
