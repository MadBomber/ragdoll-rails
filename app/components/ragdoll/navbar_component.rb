# frozen_string_literal: true

module Ragdoll
  class NavbarComponent < ApplicationComponent
    def initialize(brand_text: 'Ragdoll Engine', brand_path: nil)
      @brand_text = brand_text
      @brand_path = brand_path || main_app.root_path
    end

    private

    attr_reader :brand_text, :brand_path

    def nav_items
      [
        { text: 'Dashboard', path: ragdoll.dashboard_index_path, icon: 'fas fa-tachometer-alt' },
        { text: 'Documents', path: ragdoll.documents_path, icon: 'fas fa-file-alt' },
        { text: 'Search', path: ragdoll.search_index_path, icon: 'fas fa-search' },
        { text: 'Jobs', path: ragdoll.jobs_path, icon: 'fas fa-tasks' },
        { text: 'Analytics', path: ragdoll.analytics_path, icon: 'fas fa-chart-line' },
        { text: 'Configuration', path: ragdoll.configuration_path, icon: 'fas fa-cog' }
      ]
    end

    def nav_link_classes(path)
      base_classes = ['nav-link']
      base_classes << 'active' if current_page?(path)
      base_classes.join(' ')
    end
  end
end