# frozen_string_literal: true

module Ragdoll
  class StatsCardComponent < ApplicationComponent
    def initialize(title:, value:, icon:, color: 'primary', description: nil)
      @title = title
      @value = value
      @icon = icon
      @color = color
      @description = description
    end

    private

    attr_reader :title, :value, :icon, :color, :description
  end
end