# This file defines the gemspec for the Ragdoll gem, including its dependencies and metadata.

# frozen_string_literal: true

require_relative "lib/ragdoll/version"

Gem::Specification.new do |spec|
  spec.name        = "ragdoll"
  spec.version     = Ragdoll::VERSION
  spec.authors     = ["Dewayne VanHoozer"]
  spec.email       = ["dvanhoozer@gmail.com"]

  spec.summary     = "Ruby gem to assist in RAG - retrieval augmented generation"
  spec.description = "Ragdoll uses ActiveRecord to access a PostgreSQL " \
                     "database using pgvector for RAG operations."
  spec.homepage    = "https://github.com/MadBomber/ragdoll"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been
  # added into git.
  gemspec = File.basename(__FILE__)
  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  
  spec.add_dependency "pg", "~> 1.5"
  spec.add_dependency "pgvector", "~> 0.2"
  spec.add_dependency "ai_client", "~> 0.1"
  spec.add_dependency "thor", "~> 1.2"

  spec.add_development_dependency "minitest-rails", "~> 7.0"
  spec.add_development_dependency "factory_bot_rails", "~> 6.2"
  spec.add_development_dependency "rspec", "~> 3.12"

  spec.add_dependency "rails", "~> 7.1"
end

