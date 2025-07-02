# frozen_string_literal: true

module Ragdoll
  class Document < ApplicationRecord
    validates :metadata, presence: true

    searchkick text_middle: [:metadata_name, :metadata_summary]

    has_many :embeddings, class_name: 'Ragdoll::Embedding', foreign_key: 'document_id', dependent: :destroy

    def search_data
      {
        metadata_name: metadata['name'],
        metadata_summary: metadata['summary']
      }
    end
    has_one_attached :file
  end
end
