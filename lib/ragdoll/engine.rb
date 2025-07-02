# frozen_string_literal: true

require "rails/engine"
require "pgvector"
require "sidekiq"
require "ruby/openai"

module Ragdoll
  class Engine < ::Rails::Engine
    isolate_namespace Ragdoll
    
    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot
      g.factory_bot dir: 'spec/factories'
      g.assets false
      g.helper false
    end

    initializer "ragdoll.configure_active_job" do |app|
      app.config.active_job.queue_adapter = :sidekiq if Rails.env.production?
    end

    initializer "ragdoll.configure_pgvector" do |app|
      ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS vector") if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
    rescue ActiveRecord::NoDatabaseError, PG::ConnectionBad
      # Database doesn't exist yet, skip extension creation
    end
  end
end
