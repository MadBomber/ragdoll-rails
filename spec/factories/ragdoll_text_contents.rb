# frozen_string_literal: true

FactoryBot.define do
  factory :ragdoll_text_content, class: 'Ragdoll::TextContent' do
    association :document, factory: :ragdoll_document
    content { "This is test text content for the document." }
    embedding_model { "text-embedding-3-small" }
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