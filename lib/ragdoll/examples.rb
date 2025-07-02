# frozen_string_literal: true

# Usage examples for the Ragdoll API
# These examples show how to integrate Ragdoll into Rails applications

module Ragdoll
  module Examples
    # Example 1: Basic RAG implementation in a Rails controller
    def self.basic_rag_controller_example
      <<~RUBY
        class ChatController < ApplicationController
          def ask
            user_question = params[:question]
            
            # Get context-enhanced prompt using Ragdoll
            enhanced = Ragdoll.enhance_prompt(
              user_question,
              context_limit: 5,
              threshold: 0.7
            )
            
            # Send enhanced prompt to your AI service
            ai_response = YourAIService.complete(enhanced[:enhanced_prompt])
            
            render json: {
              answer: ai_response,
              sources: enhanced[:context_sources],
              context_used: enhanced[:context_count] > 0
            }
          end
        end
      RUBY
    end

    # Example 2: Document management in a Rails service
    def self.document_service_example
      <<~RUBY
        class DocumentService
          def initialize
            @ragdoll = Ragdoll::Client.new
          end
          
          def import_knowledge_base(directory_path)
            result = @ragdoll.add_directory(
              directory_path,
              recursive: true,
              process_immediately: false
            )
            
            Rails.logger.info "Imported \#{result[:processed]} documents"
            result
          end
          
          def search_knowledge(query, limit: 10)
            @ragdoll.search(query, limit: limit, threshold: 0.6)
          end
          
          def get_stats
            @ragdoll.stats
          end
        end
      RUBY
    end

    # Example 3: Custom RAG implementation with filtering
    def self.filtered_search_example
      <<~RUBY
        class ProductSupportBot
          def initialize
            @ragdoll = Ragdoll::Client.new
          end
          
          def answer_support_question(question, product_type: nil)
            filters = {}
            filters[:document_type] = 'pdf' if product_type # Only search manuals
            
            context = @ragdoll.get_context(
              question,
              limit: 3,
              threshold: 0.8,
              filters: filters
            )
            
            if context[:total_chunks] > 0
              prompt = build_support_prompt(question, context[:combined_context])
              ai_response = call_ai_service(prompt)
              
              {
                answer: ai_response,
                confidence: :high,
                sources: context[:context_chunks].map { |c| c[:source] }
              }
            else
              {
                answer: "I don't have specific information about that.",
                confidence: :low,
                sources: []
              }
            end
          end
          
          private
          
          def build_support_prompt(question, context)
            "Based on the following product documentation, please answer the user's question.
            
            Documentation:
            \#{context}
            
            Question: \#{question}
            
            Answer:"
          end
          
          def call_ai_service(prompt)
            # Your AI integration here
            OpenAI.complete(prompt)
          end
        end
      RUBY
    end

    # Example 4: Background job for bulk document processing
    def self.background_processing_example
      <<~RUBY
        class ProcessDocumentsJob < ApplicationJob
          def perform(user_id, file_paths)
            user = User.find(user_id)
            ragdoll = Ragdoll::Client.new
            
            results = []
            file_paths.each do |file_path|
              begin
                result = ragdoll.add_file(
                  file_path,
                  process_immediately: true,
                  metadata: { user_id: user_id }
                )
                results << { file: file_path, status: 'success', document_id: result[:id] }
              rescue => e
                results << { file: file_path, status: 'error', error: e.message }
                Rails.logger.error "Failed to process \#{file_path}: \#{e.message}"
              end
            end
            
            # Notify user of completion
            UserMailer.documents_processed(user, results).deliver_now
          end
        end
      RUBY
    end

    # Example 5: Rails initializer configuration
    def self.configuration_example
      <<~RUBY
        # config/initializers/ragdoll.rb
        Ragdoll.configure do |config|
          config.openai_api_key = ENV['OPENAI_API_KEY']
          config.embedding_model = 'text-embedding-3-large'
          config.chunk_size = 1200
          config.chunk_overlap = 300
          config.search_similarity_threshold = 0.75
          config.max_search_results = 15
          config.enable_search_analytics = true
          
          # Custom prompt template
          config.prompt_template = <<~TEMPLATE
            You are a helpful AI assistant for our company.
            Use the following context to answer questions accurately.
            
            Context:
            {{context}}
            
            Question: {{prompt}}
            
            Please provide a detailed answer based on the context:
          TEMPLATE
        end
      RUBY
    end

    # Example 6: API wrapper for external services
    def self.api_wrapper_example
      <<~RUBY
        class RagdollAPIWrapper
          include Ragdoll::Examples
          
          def initialize
            @client = Ragdoll::Client.new
          end
          
          # REST API endpoint
          def search_endpoint(params)
            begin
              results = @client.search(
                params[:query],
                limit: params[:limit] || 10,
                threshold: params[:threshold] || 0.7,
                filters: params[:filters] || {}
              )
              
              { status: 'success', data: results }
            rescue Ragdoll::SearchError => e
              { status: 'error', message: e.message }
            end
          end
          
          # GraphQL resolver
          def resolve_similar_content(query:, limit: 10)
            @client.search(query, limit: limit)[:results]
          end
          
          # Health check
          def health_check
            {
              status: @client.healthy? ? 'ok' : 'error',
              stats: @client.stats,
              timestamp: Time.current
            }
          end
        end
      RUBY
    end

    # Example 7: Testing helpers
    def self.testing_example
      <<~RUBY
        # spec/support/ragdoll_helpers.rb
        module RagdollHelpers
          def setup_test_documents
            @ragdoll = Ragdoll::Client.new
            
            # Add test documents
            @doc1 = @ragdoll.add_text(
              "Ruby on Rails is a web framework",
              title: "Rails Intro",
              process_immediately: true
            )
            
            @doc2 = @ragdoll.add_text(
              "PostgreSQL is a relational database",
              title: "Database Guide", 
              process_immediately: true
            )
          end
          
          def search_for(query)
            @ragdoll.search(query, limit: 5)
          end
          
          def enhance_prompt(prompt)
            @ragdoll.enhance_prompt(prompt, context_limit: 3)
          end
        end
        
        # In your specs
        RSpec.describe ChatController do
          include RagdollHelpers
          
          before { setup_test_documents }
          
          it "provides relevant context for questions" do
            enhanced = enhance_prompt("What is Rails?")
            expect(enhanced[:context_count]).to be > 0
            expect(enhanced[:enhanced_prompt]).to include("Ruby on Rails")
          end
        end
      RUBY
    end
  end
end