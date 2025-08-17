# frozen_string_literal: true

module Ragdoll
  class EmptyStateComponent < ApplicationComponent
    def initialize(title:, message:, icon: nil, action_path: nil, action_text: nil)
      @title = title
      @message = message
      @icon = icon
      @action_path = action_path
      @action_text = action_text
    end

    private

    attr_reader :title, :message, :icon, :action_path, :action_text
  end
end