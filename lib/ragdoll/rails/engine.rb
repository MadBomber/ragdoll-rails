# frozen_string_literal: true

require 'rails/engine'

module Ragdoll
  module Rails
    class Engine < ::Rails::Engine
      isolate_namespace Ragdoll::Rails

      config.generators do |g|
        g.test_framework :rspec
        g.fixture_replacement :factory_bot
        g.factory_bot dir: 'spec/factories'
      end

      # Ensure generators are loaded
      config.to_prepare do
        # Force load generators
        Dir.glob(File.join(__dir__, "../../../generators/**/*_generator.rb")).each do |file|
          require file
        end
      end

      # Initialize configuration after Rails has loaded
      initializer "ragdoll.configure" do |app|
        # Configure Rails-specific functionality
        # Core functionality is provided by the ragdoll gem
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