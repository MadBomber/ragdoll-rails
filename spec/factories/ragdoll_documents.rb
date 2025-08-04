# frozen_string_literal: true

FactoryBot.define do
  factory :ragdoll_document, class: 'Ragdoll::Document' do
    sequence(:location) { |n| "test://document-#{n}" }
    title { "Test Document" }
    document_type { "text" }
    source_type { "test" }
    metadata { {} }
    summary { "" }
    keywords { "" }
    status { "pending" }

    trait :completed do
      status { "completed" }
      processing_started_at { 1.hour.ago }
      processing_finished_at { 30.minutes.ago }
    end

    trait :processing do
      status { "processing" }
      processing_started_at { 5.minutes.ago }
    end

    trait :failed do
      status { "failed" }
      processing_started_at { 1.hour.ago }
      processing_finished_at { 30.minutes.ago }
    end

    trait :pdf do
      document_type { "pdf" }
      location { "test://document.pdf" }
      metadata do
        {
          page_count: 5,
          author: "Test Author",
          title: "PDF Test Document"
        }
      end
    end

    trait :docx do
      document_type { "docx" }
      location { "test://document.docx" }
      metadata do
        {
          paragraph_count: 10,
          table_count: 2,
          author: "Test Author"
        }
      end
    end

    trait :markdown do
      document_type { "markdown" }
      location { "test://document.md" }
    end

    trait :with_embeddings do
      after(:create) do |document|
        # Create text content first, then embeddings
        text_content = create(:ragdoll_text_content, document: document, content: "Test content for embeddings")
        create_list(:ragdoll_embedding, 3, embeddable: text_content)
      end
    end

    trait :large_content do
      after(:create) do |document|
        create(:ragdoll_text_content, document: document, content: "Large content. " * 1000)
      end
    end

    trait :with_summary do
      summary { "This is a generated summary of the document content." }
      summary_generated_at { 1.hour.ago }
      summary_model { "gpt-4" }
    end

    trait :needs_summary do
      summary { nil }
      after(:create) do |document|
        create(:ragdoll_text_content, document: document, content: "This is a document with enough content to warrant a summary. " * 50)
      end
    end

    trait :stale_summary do
      summary { "This is an old summary that needs updating." }
      summary_generated_at { 2.days.ago }
      summary_model { "gpt-3.5-turbo" }
      updated_at { 1.day.ago }
    end
  end
end