# frozen_string_literal: true

require 'rails/engine'

module Ragdoll
  module Rails
    class Engine < ::Rails::Engine
      isolate_namespace Ragdoll
      engine_name 'ragdoll'

      # Configure the engine to use migrations from the ragdoll gem
      # Find the ragdoll gem path
      begin
        ragdoll_path = Gem::Specification.find_by_name('ragdoll').gem_dir
      rescue Gem::MissingSpecError
        # If not found as a gem (e.g., using path in Gemfile), try to find it relative to this engine
        ragdoll_path = File.expand_path("../../../../ragdoll", __dir__)
      end
      
      migration_path = File.join(ragdoll_path, 'db/migrate')
      
      # Set the migration paths for this engine to point to ragdoll gem
      if File.exist?(migration_path)
        config.paths["db/migrate"] = [migration_path]
      end

      config.generators do |g|
        g.test_framework :rspec
        g.fixture_replacement :factory_bot
        g.factory_bot dir: 'spec/factories'
      end

      # Initialize configuration after Rails has loaded
      initializer "ragdoll.configure" do |app|
        # Configure Rails-specific functionality
        # Core functionality is provided by the ragdoll gem
        
        # Ensure ViewComponent autoloading for engine components
        app.config.autoload_paths += ["#{root}/app/components"]
        
        # Configure ViewComponent
        if ::Rails.env.development? && app.config.respond_to?(:view_component)
          app.config.view_component.preview_paths ||= []
          app.config.view_component.preview_paths << "#{root}/spec/components/previews"
        end
        
        # Configure ActionCable for the engine
        # Load cable configuration from engine's config/cable.yml
        cable_config_file = File.join(root, 'config', 'cable.yml')
        if File.exist?(cable_config_file)
          cable_config = ::Rails.application.config_for(cable_config_file)
          if cable_config
            # Apply cable configuration to the main application
            app.config.action_cable.mount_path ||= '/cable'
            
            # Set adapter if not already configured
            unless app.config.action_cable.adapter
              app.config.action_cable.adapter = cable_config['adapter']
              app.config.action_cable.url = cable_config['url'] if cable_config['url']
              app.config.action_cable.channel_prefix = cable_config['channel_prefix'] if cable_config['channel_prefix']
            end
          end
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