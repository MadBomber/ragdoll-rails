# frozen_string_literal: true

module Ragdoll
  class Embedding < ApplicationRecord
    validates :document, presence: true

    searchkick text_middle: [:metadata_content, :metadata_propositions]

    belongs_to :document

    def search_data
      {
        metadata_content: metadata['content'],
        metadata_propositions: metadata['propositions']
      }
    end

    # Assuming the vector column is named 'vector'
    neighbor :vector, method: :euclidean
  end
end
