# frozen_string_literal: true

FactoryBot.define do
  factory :ragdoll_unified_document, class: 'Ragdoll::UnifiedDocument' do
    sequence(:title) { |n| "Unified Document #{n}" }
    location { "/path/to/document.txt" }
    document_type { "text" }
    status { "processed" }
    metadata { {} }

    trait :with_content do
      after(:create) do |document|
        create(:ragdoll_unified_content, unified_document: document)
      end
    end

    trait :image_document do
      title { "Test Image" }
      location { "/path/to/image.jpg" }
      document_type { "image" }

      after(:create) do |document|
        create(:ragdoll_unified_content, :image_description, unified_document: document)
      end
    end

    trait :audio_document do
      title { "Test Audio" }
      location { "/path/to/audio.mp3" }
      document_type { "audio" }

      after(:create) do |document|
        create(:ragdoll_unified_content, :audio_transcript, unified_document: document)
      end
    end

    trait :csv_document do
      title { "Data File" }
      location { "/path/to/data.csv" }
      document_type { "csv" }

      after(:create) do |document|
        create(:ragdoll_unified_content, :csv_data, unified_document: document)
      end
    end

    trait :pending do
      status { "pending" }
    end

    trait :processing do
      status { "processing" }
    end

    trait :failed do
      status { "failed" }
      metadata { { error: "Processing failed" } }
    end
  end
end