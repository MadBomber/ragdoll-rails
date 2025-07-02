# frozen_string_literal: true

FactoryBot.define do
  factory :ragdoll_search, class: 'Ragdoll::Search' do
    query { "How to configure database?" }
    sequence(:query_embedding) { |n| Array.new(1536) { |i| (n + i) / 1000000.0 } }
    search_type { "semantic" }
    filters { {} }
    results { { result_ids: [1, 2, 3] } }
    result_count { 3 }
    search_time { 0.15 }
    model_name { "text-embedding-3-small" }

    trait :with_filters do
      filters { { document_type: "pdf", status: "completed" } }
    end

    trait :slow_search do
      search_time { 2.5 }
    end

    trait :no_results do
      results { { result_ids: [] } }
      result_count { 0 }
      search_time { 0.05 }
    end

    trait :many_results do
      results { { result_ids: (1..50).to_a } }
      result_count { 50 }
      search_time { 0.8 }
    end

    trait :complex_query do
      query { "How do I set up authentication and authorization in Rails with Devise and CanCan?" }
    end
  end
end