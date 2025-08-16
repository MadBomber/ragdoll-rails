# frozen_string_literal: true

module Ragdoll
  class AlertComponent < ApplicationComponent
    def initialize(message:, type: 'info', dismissible: true, **options)
      @message = message
      @type = type
      @dismissible = dismissible
      @options = options
    end

    private

    attr_reader :message, :type, :dismissible, :options

    def alert_classes
      classes = ['alert', "alert-#{type}"]
      classes << 'alert-dismissible' if dismissible
      classes << 'fade show' if dismissible
      classes << options[:class] if options[:class]
      classes.join(' ')
    end

    def dismiss_button
      return unless dismissible

      content_tag :button, type: 'button', class: 'btn-close', data: { bs_dismiss: 'alert' } do
        ''
      end
    end
  end
end