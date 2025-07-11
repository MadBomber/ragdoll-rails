# This file defines the Embedding model for the Ragdoll gem.

# frozen_string_literal: true

module Ragdoll
  class Embedding < ApplicationRecord
    searchkick text_middle: [:metadata_content, :metadata_propositions] if defined?(Searchkick)

    belongs_to :document

    # Override dangerous attribute to allow access to model_name column
    def self.dangerous_attribute_method?(name)
      name.to_s == 'model_name' ? false : super
    end

    def search_data
      return {} unless defined?(Searchkick)
      
      {
        metadata_content: metadata['content'],
        metadata_propositions: metadata['propositions']
      }
    end

    # Assuming the vector column is named 'vector'
    neighbor :vector, method: :euclidean if respond_to?(:neighbor)
  end
end
