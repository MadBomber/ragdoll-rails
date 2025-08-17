# frozen_string_literal: true

module Ragdoll
  module Api
    module V1
      class DocumentsController < BaseController
        before_action :set_document, only: [:show, :update, :destroy, :reprocess]
        
        def index
          documents = ::Ragdoll::Document.all
          documents = documents.where(status: params[:status]) if params[:status].present?
          documents = documents.where(document_type: params[:document_type]) if params[:document_type].present?
          documents = documents.order(created_at: :desc)
          
          render json: {
            documents: documents.map(&method(:document_json)),
            total: documents.count
          }
        end
        
        def show
          render json: {
            document: document_json(@document),
            embeddings: @document.all_embeddings.map(&method(:embedding_json))
          }
        end
        
        def create
          begin
            if params[:file].present?
              # Handle file upload
              temp_path = Rails.root.join('tmp', 'uploads', params[:file].original_filename)
              FileUtils.mkdir_p(File.dirname(temp_path))
              File.binwrite(temp_path, params[:file].read)
              
              result = ::Ragdoll.add_document(path: temp_path.to_s)
              
              if result[:success] && result[:document_id]
                document = ::Ragdoll::Document.find(result[:document_id])
                File.delete(temp_path) if File.exist?(temp_path)
                render json: { document: document_json(document) }, status: :created
              else
                File.delete(temp_path) if File.exist?(temp_path)
                return render_error(result[:error] || "Failed to create document")
              end
            elsif params[:content].present?
              # Handle text content
              temp_path = Rails.root.join('tmp', 'uploads', "#{SecureRandom.hex(8)}.txt")
              FileUtils.mkdir_p(File.dirname(temp_path))
              File.write(temp_path, params[:content])
              
              result = ::Ragdoll.add_document(path: temp_path.to_s)
              
              if result[:success] && result[:document_id]
                document = ::Ragdoll::Document.find(result[:document_id])
                File.delete(temp_path) if File.exist?(temp_path)
                render json: { document: document_json(document) }, status: :created
              else
                File.delete(temp_path) if File.exist?(temp_path)
                return render_error(result[:error] || "Failed to create document")
              end
            else
              return render_error("Either file or content must be provided")
            end
            
          rescue => e
            render_error(e.message)
          end
        end
        
        def update
          begin
            if @document.update(document_params)
              render json: { document: document_json(@document) }
            else
              render_error(@document.errors.full_messages.join(', '))
            end
          rescue => e
            render_error(e.message)
          end
        end
        
        def destroy
          begin
            @document.destroy
            render_success({}, "Document deleted successfully")
          rescue => e
            render_error(e.message)
          end
        end
        
        def reprocess
          begin
            @document.all_embeddings.destroy_all
            @document.update(status: 'pending')
            ::Ragdoll::GenerateEmbeddingsJob.perform_later(@document.id)
            
            render_success({}, "Document reprocessing initiated")
          rescue => e
            render_error(e.message)
          end
        end
        
        private
        
        def set_document
          @document = ::Ragdoll::Document.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render_error("Document not found", :not_found)
        end
        
        def document_params
          params.require(:document).permit(:title, :content, :metadata, :status)
        end
        
        def document_json(document)
          {
            id: document.id,
            title: document.title,
            content: document.content,
            document_type: document.document_type,
            location: document.location,
            metadata: document.metadata,
            status: document.status,
            character_count: document.total_character_count,
            word_count: document.total_word_count,
            embedding_count: document.all_embeddings.count,
            created_at: document.created_at,
            updated_at: document.updated_at
          }
        end
        
        def embedding_json(embedding)
          {
            id: embedding.id,
            content: embedding.content,
            chunk_index: embedding.chunk_index,
            model_name: embedding.model_name,
            vector_dimensions: embedding.embedding_dimensions,
            usage_count: embedding.usage_count,
            last_used_at: embedding.returned_at,
            created_at: embedding.created_at
          }
        end
      end
    end
  end
end