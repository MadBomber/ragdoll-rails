# frozen_string_literal: true

FactoryBot.define do
  factory :ragdoll_embedding, class: 'Ragdoll::Embedding' do
    association :embeddable, factory: :ragdoll_unified_content
    sequence(:embedding_vector) { |n| Array.new(1536) { |i| (n + i) / 1000000.0 } }
    model_name { "text-embedding-3-small" }
    token_count { 25 }
    sequence(:chunk_index) { |n| n }
    metadata { { chunk_length: 50, word_count: 10 } }
    usage_count { 0 }
    returned_at { nil }

    trait :high_similarity do
      # Create an embedding with known values for similarity testing
      embedding_vector { Array.new(1536, 0.5) }
    end

    trait :low_similarity do
      # Create a very different embedding
      embedding_vector { Array.new(1536) { |i| (i * 0.001) - 0.5 } }
    end

    trait :large_chunk do
      token_count { 300 }
      metadata { { chunk_length: 2000, word_count: 200 } }
      after(:create) do |embedding|
        embedding.embeddable.update(content: "Large chunk content. " * 100)
      end
    end

    trait :code_content do
      metadata { { language: "ruby", chunk_length: 100, word_count: 15 } }
      after(:create) do |embedding|
        code_content = <<~CODE
          def example_method(param)
            return param.upcase if param.is_a?(String)
            param
          end
        CODE
        embedding.embeddable.update(content: code_content)
      end
    end

    trait :question_content do
      metadata { { content_type: "question", chunk_length: 42, word_count: 8 } }
      after(:create) do |embedding|
        embedding.embeddable.update(content: "How do I configure the database connection?")
      end
    end

    trait :different_model do
      model_name { "text-embedding-3-large" }
      embedding_vector { Array.new(3072) { |i| i / 1000000.0 } } # Different dimension
    end

    trait :used_once do
      usage_count { 1 }
      returned_at { 1.day.ago }
    end

    trait :frequently_used do
      usage_count { 10 }
      returned_at { 1.hour.ago }
    end

    trait :recently_used do
      usage_count { 3 }
      returned_at { 30.minutes.ago }
    end

    trait :old_usage do
      usage_count { 5 }
      returned_at { 30.days.ago }
    end

    trait :never_used do
      usage_count { 0 }
      returned_at { nil }
    end
  end
end