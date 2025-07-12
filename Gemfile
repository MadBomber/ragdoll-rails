# madbomber/ragdoll-rails/Gemfile

source "https://rubygems.org"

gemspec name: "ragdoll-rails"

# Local development dependency on ragdoll-core
gem "ragdoll-core", path: "../ragdoll-core"

# Additional development/test gems not in gemspec
gem "amazing_print" # Pretty print Ruby objects with proper indentation and colors
gem "debug_me"      # A tool to print the labeled value of variables.
gem "neighbor"      # Nearest neighbor search for Rails
gem "solid_queue"   # Database-backed Active Job backend.
gem "searchkick"    # Elasticsearch-backed search for Rails

group :development do
  gem "annotate"    # Annotate models, routes, fixtures, and others based on the database schema
  gem 'claude-on-rails'
end
