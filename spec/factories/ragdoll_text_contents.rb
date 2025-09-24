# frozen_string_literal: true

# DEPRECATED: This factory is deprecated. Use :ragdoll_unified_content instead.
# Kept for backward compatibility during migration.

FactoryBot.define do
  # Alias for unified content to maintain backward compatibility
  factory :ragdoll_text_content, class: 'Ragdoll::UnifiedContent' do
    association :unified_document, factory: :ragdoll_unified_document
    content { "This is test text content for the document." }
    original_media_type { "text" }
    conversion_method { "direct" }
    content_quality_score { 0.85 }
    word_count { 8 }
    character_count { 45 }
    embedding_model { "text-embedding-3-large" }
    metadata { {} }

    trait :large_content do
      content { "Large text content. " * 500 }
    end

    trait :markdown_content do
      content { "# Test Document\n\nThis is a **markdown** document with formatting." }
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
    end

    trait :json_content do
      content { '{"title": "Test Document", "description": "A test JSON document"}' }
    end
  end
end