# frozen_string_literal: true

require 'rails/generators'

module Ragdoll
  class InitGenerator < ::Rails::Generators::Base
    desc "Create Ragdoll configuration initializer"
    source_root File.expand_path("init/templates", __dir__)

    def create_initializer_file
      template "ragdoll_config.rb", "config/initializers/ragdoll_config.rb"
    end

    def show_readme
      readme "INSTALL" if behavior == :invoke
    end

    private

    def application_name
      ::Rails.application.class.name.split("::").first.underscore
    end
  end
end