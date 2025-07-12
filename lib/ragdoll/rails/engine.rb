# frozen_string_literal: true

require 'rails/engine'

module Ragdoll
  module Rails
    class Engine < ::Rails::Engine
      isolate_namespace Ragdoll

      config.generators do |g|
        g.test_framework :rspec
        g.fixture_replacement :factory_bot
        g.factory_bot dir: 'spec/factories'
      end

      # Initialize configuration after Rails has loaded
      initializer "ragdoll.configure" do |app|
        # Configure Ragdoll::Core to use ActiveRecord storage by default
        Ragdoll::Core.configure do |config|
          config.storage_backend = :activerecord
          config.storage_config = {
            document_model: Ragdoll::Document,
            embedding_model: Ragdoll::Embedding
          }
        end
      end

      # Ensure models are eager loaded in production
      initializer "ragdoll.eager_load", after: "finisher_hook" do |app|
        if ::Rails.env.production?
          app.config.eager_load_paths += [
            "#{root}/app/models/ragdoll"
          ]
        end
      end
    end
  end
end