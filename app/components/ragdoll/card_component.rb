# frozen_string_literal: true

module Ragdoll
  class CardComponent < ApplicationComponent
    def initialize(title: nil, icon: nil, **options)
      @title = title
      @icon = icon
      @options = options
    end

    private

    attr_reader :title, :icon, :options

    def card_classes
      classes = ['card']
      classes << options[:class] if options[:class]
      classes.join(' ')
    end
  end
end