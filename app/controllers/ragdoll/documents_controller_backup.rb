# Backup controller for simple upload without ActionCable/jobs
# This is a fallback version for when job queues are not available

module Ragdoll
  class DocumentsControllerBackup < ApplicationController
    def upload_simple
      Rails.logger.info "upload_simple called with params: #{params.inspect}"
      
      if params[:ragdoll_document] && params[:ragdoll_document][:files].present?
        uploaded_files = params[:ragdoll_document][:files]
        uploaded_files = [uploaded_files] unless uploaded_files.is_a?(Array)
        
        results = []
        uploaded_files.each_with_index do |file, index|
          next unless file.respond_to?(:original_filename)
          
          begin
            # Save uploaded file temporarily
            temp_path = Rails.root.join('tmp', 'uploads', file.original_filename)
            FileUtils.mkdir_p(File.dirname(temp_path))
            File.binwrite(temp_path, file.read)
            
            # Process document directly (synchronously)
            result = ::Ragdoll.add_document(path: temp_path.to_s)
            
            if result[:success] && result[:document_id]
              document = ::Ragdoll::Document.find(result[:document_id])
              results << { 
                file: file.original_filename, 
                success: true, 
                document_id: document.id,
                message: 'Document processed successfully'
              }
            else
              results << { 
                file: file.original_filename, 
                success: false, 
                error: result[:error] || 'Unknown error'
              }
            end
            
            # Clean up temp file
            File.delete(temp_path) if File.exist?(temp_path)
          rescue => e
            Rails.logger.error "Error processing file #{file.original_filename}: #{e.message}"
            results << { 
              file: file.original_filename, 
              success: false, 
              error: e.message
            }
          end
        end
        
        render json: { 
          success: true, 
          results: results,
          message: "Processed #{results.count} file(s)" 
        }
      else
        render json: { success: false, error: "No files provided" }, status: :bad_request
      end
    rescue => e
      Rails.logger.error "Error in upload_simple: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { success: false, error: e.message }, status: :internal_server_error
    end
  end
end