# frozen_string_literal: true

module Ragdoll
  class FlashMessagesComponent < ApplicationComponent
    def initialize(flash:)
      @flash = flash
    end

    private

    attr_reader :flash

    def flash_type_to_alert_type(type)
      case type.to_s
      when 'notice'
        'success'
      when 'alert'
        'danger'
      when 'error'
        'danger'
      when 'warning'
        'warning'
      else
        'info'
      end
    end

    def flash_messages
      flash.map do |type, message|
        {
          type: flash_type_to_alert_type(type),
          message: message
        }
      end
    end
  end
end