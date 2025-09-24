# frozen_string_literal: true

FactoryBot.define do
  factory :ragdoll_unified_content, class: 'Ragdoll::UnifiedContent' do
    association :unified_document, factory: :ragdoll_unified_document
    content { "This is test unified content for the document." }
    original_media_type { "text" }
    conversion_method { "direct" }
    content_quality_score { 0.85 }
    word_count { 7 }
    character_count { 42 }
    embedding_model { "text-embedding-3-large" }
    metadata { {} }

    trait :image_description do
      content { "A landscape photograph showing mountains in the background with a lake in the foreground. The sky is clear blue with scattered white clouds." }
      original_media_type { "image" }
      conversion_method { "image_to_text" }
      content_quality_score { 0.75 }
      word_count { 20 }
      character_count { 120 }
    end

    trait :audio_transcript do
      content { "Welcome to our podcast. Today we're discussing machine learning applications in healthcare." }
      original_media_type { "audio" }
      conversion_method { "audio_transcription" }
      content_quality_score { 0.90 }
      word_count { 12 }
      character_count { 85 }
    end

    trait :csv_data do
      content { "name: John Smith, age: 30, department: Engineering\nname: Jane Doe, age: 28, department: Marketing" }
      original_media_type { "csv" }
      conversion_method { "csv_extraction" }
      content_quality_score { 0.80 }
      word_count { 14 }
      character_count { 95 }
    end

    trait :low_quality do
      content { "Short content." }
      content_quality_score { 0.20 }
      word_count { 2 }
      character_count { 13 }
    end

    trait :high_quality do
      content { "Large comprehensive text content. " * 100 }
      content_quality_score { 0.95 }
      word_count { 400 }
      character_count { 3500 }
    end

    trait :markdown_content do
      content { "# Test Document\n\nThis is a **markdown** document with formatting." }
      original_media_type { "markdown" }
      conversion_method { "text_extraction" }
    end

    trait :code_content do
      content do
        <<~CODE
          def example_method(param)
            return param.upcase if param.is_a?(String)
            param
          end
        CODE
      end
      original_media_type { "code" }
      conversion_method { "direct" }
    end

    trait :json_content do
      content { 'title: Test Document, description: A test JSON document' }
      original_media_type { "json" }
      conversion_method { "json_extraction" }
    end
  end
end