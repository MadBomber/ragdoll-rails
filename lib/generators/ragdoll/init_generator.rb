# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'

module Ragdoll
  class InitGenerator < ::Rails::Generators::Base
    include ::Rails::Generators::Migration
    
    desc "Create Ragdoll configuration initializer and install migrations"
    source_root File.expand_path("init/templates", __dir__)

    def create_initializer_file
      template "ragdoll_config.rb", "config/initializers/ragdoll_config.rb"
    end

    def copy_migrations
      say "Installing Ragdoll migrations..."
      
      # Find the ragdoll gem path
      begin
        ragdoll_path = Gem::Specification.find_by_name('ragdoll').gem_dir
      rescue Gem::MissingSpecError
        # If not found as a gem (e.g., using path in Gemfile), try to find it relative to this engine
        ragdoll_path = File.expand_path("../../../../../ragdoll", __dir__)
      end
      
      migration_source_path = File.join(ragdoll_path, 'db/migrate')
      
      if File.exist?(migration_source_path)
        Dir.glob("#{migration_source_path}/*.rb").each do |migration_file|
          migration_name = File.basename(migration_file)
          
          # Check if migration already exists in the app
          if migration_exists?(migration_name)
            say_status "skip", migration_name, :yellow
          else
            copy_file migration_file, "db/migrate/#{migration_name}"
            say_status "copied", migration_name, :green
          end
        end
      else
        say "Warning: Could not find Ragdoll migrations at #{migration_source_path}", :red
      end
    end

    def show_readme
      readme "INSTALL" if behavior == :invoke
    end

    private

    def application_name
      ::Rails.application.class.name.split("::").first.underscore
    end
    
    def migration_exists?(filename)
      Dir.glob("#{destination_root}/db/migrate/*.rb").any? do |existing_file|
        File.basename(existing_file) == filename
      end
    end
    
    # Required for Rails::Generators::Migration
    def self.next_migration_number(dirname)
      ::ActiveRecord::Generators::Base.next_migration_number(dirname)
    end
  end
end