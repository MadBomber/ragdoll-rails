# frozen_string_literal: true

require_relative 'rails/version'
require_relative 'rails/configuration'
begin
  require_relative 'rails/engine'
rescue LoadError, NameError => e
  # Skip engine loading if Rails is not available (e.g., in tests)
  puts "Warning: Could not load Rails engine: #{e.message}" if ENV['RAGDOLL_VERBOSE']
end

module Ragdoll
  module Rails
    # Rails engine specific functionality
    # Core business logic is provided by the ragdoll gem
    
    def self.configuration
      @configuration ||= Configuration.new
    end
    
    def self.configure
      yield(configuration)
      # Delegate core configuration to the ragdoll gem
      configure_ragdoll_core if defined?(::Ragdoll.configure)
    end
    
    private
    
    def self.configure_ragdoll_core
      # This method would configure the core ragdoll gem
      # based on Rails-specific settings
    end
  end
end