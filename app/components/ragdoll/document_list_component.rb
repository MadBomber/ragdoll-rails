# frozen_string_literal: true

module Ragdoll
  class DocumentListComponent < ApplicationComponent
    def initialize(documents:)
      @documents = documents
    end

    private

    attr_reader :documents
  end
end