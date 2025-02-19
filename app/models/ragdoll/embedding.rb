# This file defines the Embedding model for the Ragdoll gem.

# frozen_string_literal: true

module Ragdoll
  class Embedding < ApplicationRecord
    belongs_to :document
  end
end
