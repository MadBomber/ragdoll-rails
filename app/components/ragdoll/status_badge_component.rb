# frozen_string_literal: true

module Ragdoll
  class StatusBadgeComponent < ApplicationComponent
    def initialize(status:)
      @status = status
    end

    private

    attr_reader :status

    def badge_class
      case status.to_s.downcase
      when 'processed', 'completed', 'success'
        'bg-success'
      when 'failed', 'error'
        'bg-danger'
      when 'processing', 'pending', 'queued'
        'bg-warning'
      else
        'bg-secondary'
      end
    end

    def badge_text
      status.to_s.humanize
    end
  end
end