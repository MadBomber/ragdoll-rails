# frozen_string_literal: true

module Ragdoll
  class ProcessFileJob < ApplicationJob
    queue_as :default

    def perform(file_id, session_id, filename, temp_path)
      ::Rails.logger.info "🚀 Ragdoll::ProcessFileJob starting: file_id=#{file_id}, session_id=#{session_id}, filename=#{filename}"
      ::Rails.logger.info "📁 Temp file path: #{temp_path}"
      ::Rails.logger.info "📊 Temp file exists: #{File.exist?(temp_path)}"
      ::Rails.logger.info "📏 Temp file size: #{File.exist?(temp_path) ? File.size(temp_path) : 'N/A'} bytes"
      
      begin
        # Verify temp file exists before processing
        unless File.exist?(temp_path)
          raise "Temporary file not found: #{temp_path}"
        end
        
        # Broadcast start
        broadcast_data = {
          file_id: file_id,
          filename: filename,
          status: 'started',
          progress: 0,
          message: 'Starting file processing...'
        }
        
        ::Rails.logger.info "📡 Broadcasting start: #{broadcast_data}"
        begin
          ActionCable.server.broadcast("ragdoll_file_processing_#{session_id}", broadcast_data)
          ::Rails.logger.info "✅ ActionCable broadcast sent successfully"
        rescue => e
          ::Rails.logger.error "❌ ActionCable broadcast failed: #{e.message}"
          ::Rails.logger.error e.backtrace.first(3)
        end

        # Simulate progress updates during processing
        broadcast_progress(session_id, file_id, filename, 25, 'Reading file...')
        
        # Use Ragdoll to add document
        result = ::Ragdoll.add_document(path: temp_path)
        
        broadcast_progress(session_id, file_id, filename, 75, 'Generating embeddings...')
        
        if result[:success] && result[:document_id]
          document = ::Ragdoll::Document.find(result[:document_id])
          
          # Broadcast completion
          completion_data = {
            file_id: file_id,
            filename: filename,
            status: 'completed',
            progress: 100,
            message: 'Processing completed successfully',
            document_id: document.id
          }
          
          ::Rails.logger.info "🎉 Broadcasting completion: #{completion_data}"
          begin
            ActionCable.server.broadcast("ragdoll_file_processing_#{session_id}", completion_data)
            ::Rails.logger.info "✅ Completion broadcast sent successfully"
          rescue => e
            ::Rails.logger.error "❌ Completion broadcast failed: #{e.message}"
          end
        else
          raise "Processing failed: #{result[:error] || 'Unknown error'}"
        end
        
      rescue => e
        ::Rails.logger.error "💥 Ragdoll::ProcessFileJob error: #{e.message}"
        ::Rails.logger.error e.backtrace.first(5)
        
        # Broadcast error
        error_data = {
          file_id: file_id,
          filename: filename,
          status: 'error',
          progress: 0,
          message: "Error: #{e.message}"
        }
        
        ::Rails.logger.info "📡 Broadcasting error: #{error_data}"
        begin
          ActionCable.server.broadcast("ragdoll_file_processing_#{session_id}", error_data)
          ::Rails.logger.info "✅ Error broadcast sent successfully"
        rescue => e
          ::Rails.logger.error "❌ Error broadcast failed: #{e.message}"
        end
        
        # Re-raise the error to mark job as failed
        raise e
      ensure
        # ALWAYS clean up temp file in ensure block
        if temp_path && File.exist?(temp_path)
          ::Rails.logger.info "🧹 Cleaning up temp file: #{temp_path}"
          begin
            File.delete(temp_path)
            ::Rails.logger.info "✅ Temp file deleted successfully"
          rescue => e
            ::Rails.logger.error "❌ Failed to delete temp file: #{e.message}"
          end
        else
          ::Rails.logger.info "📝 Temp file already cleaned up or doesn't exist: #{temp_path}"
        end
      end
    end

    private

    def broadcast_progress(session_id, file_id, filename, progress, message)
      broadcast_data = {
        file_id: file_id,
        filename: filename,
        status: 'processing',
        progress: progress,
        message: message
      }
      
      ::Rails.logger.info "📡 Broadcasting progress: #{broadcast_data}"
      begin
        ActionCable.server.broadcast("ragdoll_file_processing_#{session_id}", broadcast_data)
        ::Rails.logger.info "✅ Progress broadcast sent successfully"
      rescue => e
        ::Rails.logger.error "❌ Progress broadcast failed: #{e.message}"
      end
      
      # Small delay to simulate processing time
      sleep(0.5)
    end
  end
end