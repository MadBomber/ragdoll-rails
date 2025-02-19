# This file defines the Document model for the Ragdoll gem.

# frozen_string_literal: true

module Ragdoll
  class Document < ApplicationRecord
    has_many :embeddings, dependent: :destroy
  end
end
