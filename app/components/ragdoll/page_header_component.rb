# frozen_string_literal: true

module Ragdoll
  class PageHeaderComponent < ApplicationComponent
    def initialize(title:, icon: nil, subtitle: nil)
      @title = title
      @icon = icon
      @subtitle = subtitle
    end

    private

    attr_reader :title, :icon, :subtitle
  end
end