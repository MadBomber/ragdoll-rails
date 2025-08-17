# frozen_string_literal: true

module Ragdoll
  class DocumentTableComponent < ViewComponent::Base
    def initialize(documents:)
      @documents = documents
    end

    private

    attr_reader :documents
  end
end