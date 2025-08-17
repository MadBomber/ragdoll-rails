# frozen_string_literal: true

module Ragdoll
  class BulkDocumentProcessingJob < ApplicationJob
    queue_as :default
    
    private
    
    def safe_log_operation(operation, details = {})
      return unless defined?(RagdollLogging)
      RagdollLogging.log_operation(operation, details)
    rescue => e
      logger.debug "Failed to log operation #{operation}: #{e.message}"
    end
    
    def safe_log_error(operation, error, details = {})
      return unless defined?(RagdollLogging)
      RagdollLogging.log_error(operation, error, details)
    rescue => e
      logger.debug "Failed to log error #{operation}: #{e.message}"
    end
    
    def safe_log_performance(operation, duration, details = {})
      return unless defined?(RagdollLogging)
      RagdollLogging.log_performance(operation, duration, details)
    rescue => e
      logger.debug "Failed to log performance #{operation}: #{e.message}"
    end
    
    def perform(session_id, file_paths_data, force_duplicate = false)
      start_time = Time.current
      
      # Initialize variables early to avoid nil errors in rescue block
      total_files = file_paths_data&.size || 0
      processed_count = 0
      failed_files = []
      
      safe_log_operation("bulk_processing_start", {
        session_id: session_id,
        file_count: total_files,
        force_duplicate: force_duplicate,
        job_id: job_id
      })
      
      logger.info "🚀 Starting bulk document processing job for session #{session_id}"
      logger.info "📁 Processing #{total_files} files"
      
      # Early return if no files to process
      if file_paths_data.nil? || file_paths_data.empty?
        logger.warn "⚠️ No files provided for processing in session #{session_id}"
        return
      end
      
      batch_size = 10  # Process 10 files at a time for async jobs
      
      file_paths_data.each_slice(batch_size).with_index do |file_batch, batch_index|
        logger.info "📦 Processing batch #{batch_index + 1} of #{(total_files.to_f / batch_size).ceil}"
        
        file_batch.each do |file_data|
          file_start_time = Time.current
          
          begin
            temp_path = file_data[:temp_path]
            original_filename = file_data[:original_filename]
            
            safe_log_operation("file_processing_start", {
              session_id: session_id,
              filename: original_filename,
              temp_path: temp_path,
              file_exists: File.exist?(temp_path),
              file_size: File.exist?(temp_path) ? File.size(temp_path) : 0
            })
            
            unless File.exist?(temp_path)
              error_msg = "Temporary file not found: #{temp_path}"
              safe_log_error("file_processing", StandardError.new(error_msg), {
                session_id: session_id,
                filename: original_filename,
                temp_path: temp_path
              })
              next
            end
            
            logger.info "🔄 Processing file: #{original_filename}"
            
            # Broadcast progress update
            progress_percentage = ((processed_count.to_f / total_files) * 100).round(1)
            ActionCable.server.broadcast("ragdoll_file_processing_#{session_id}", {
              type: 'file_progress',
              filename: original_filename,
              processed: processed_count,
              total: total_files,
              percentage: progress_percentage,
              status: 'processing'
            })
            
            # Process the document
            ragdoll_start_time = Time.current
            result = ::Ragdoll.add_document(path: temp_path, force: force_duplicate)
            ragdoll_duration = Time.current - ragdoll_start_time
            
            safe_log_performance("ragdoll_add_document", ragdoll_duration, {
              session_id: session_id,
              filename: original_filename,
              result_success: result && result[:success],
              force_duplicate: force_duplicate
            })
            
            if result && result[:success]
              processed_count += 1
              file_duration = Time.current - file_start_time
              
              safe_log_operation("file_processing_success", {
                session_id: session_id,
                filename: original_filename,
                document_id: result[:document_id],
                processing_duration: file_duration.round(3),
                processed_count: processed_count,
                total_files: total_files
              })
              
              logger.info "✅ Successfully processed: #{original_filename}"
              
              # Broadcast success
              ActionCable.server.broadcast("ragdoll_file_processing_#{session_id}", {
                type: 'file_complete',
                filename: original_filename,
                processed: processed_count,
                total: total_files,
                percentage: ((processed_count.to_f / total_files) * 100).round(1),
                status: 'completed',
                document_id: result[:document_id]
              })
            else
              failed_files << original_filename
              error_message = result ? result[:error] : 'Unknown error'
              file_duration = Time.current - file_start_time
              
              safe_log_error("file_processing", StandardError.new(error_message), {
                session_id: session_id,
                filename: original_filename,
                processing_duration: file_duration.round(3),
                ragdoll_result: result,
                temp_path: temp_path,
                file_size: File.size(temp_path)
              })
              
              logger.error "❌ Failed to process: #{original_filename} - #{error_message}"
              
              # Broadcast error
              ActionCable.server.broadcast("ragdoll_file_processing_#{session_id}", {
                type: 'file_error',
                filename: original_filename,
                processed: processed_count,
                total: total_files,
                percentage: ((processed_count.to_f / total_files) * 100).round(1),
                status: 'failed',
                error: error_message
              })
            end
            
            # Clean up temp file
            File.delete(temp_path) if File.exist?(temp_path)
            
          rescue => e
            failed_files << (file_data[:original_filename] || 'unknown file')
            file_duration = Time.current - file_start_time
            
            safe_log_error("file_processing_exception", e, {
              session_id: session_id,
              filename: file_data[:original_filename],
              temp_path: file_data[:temp_path],
              processing_duration: file_duration.round(3),
              file_data: file_data,
              processed_count: processed_count,
              total_files: total_files
            })
            
            logger.error "💥 Exception processing file #{file_data[:original_filename]}: #{e.message}"
            logger.error e.backtrace.join("\n")
            
            # Broadcast error
            ActionCable.server.broadcast("ragdoll_file_processing_#{session_id}", {
              type: 'file_error',
              filename: file_data[:original_filename],
              processed: processed_count,
              total: total_files,
              percentage: ((processed_count.to_f / total_files) * 100).round(1),
              status: 'failed',
              error: e.message
            })
          end
        end
        
        # Force garbage collection after each batch
        GC.start
        
        # Small delay between batches to prevent overwhelming the system
        sleep(0.1)
      end
      
      # Broadcast final completion
      final_percentage = 100.0
      ActionCable.server.broadcast("ragdoll_file_processing_#{session_id}", {
        type: 'bulk_complete',
        processed: processed_count,
        total: total_files,
        failed: failed_files.size,
        failed_files: failed_files,
        percentage: final_percentage,
        status: 'completed'
      })
      
      total_duration = Time.current - start_time
      
      safe_log_operation("bulk_processing_complete", {
        session_id: session_id,
        total_files: total_files,
        processed_count: processed_count,
        failed_count: failed_files.size,
        failed_files: failed_files,
        total_duration: total_duration.round(3),
        avg_file_duration: total_files > 0 ? (total_duration / total_files).round(3) : 0
      })
      
      logger.info "🎉 Bulk processing completed for session #{session_id}"
      logger.info "📊 Results: #{processed_count}/#{total_files} successful, #{failed_files.size} failed"
      
    rescue => e
      total_duration = Time.current - start_time
      
      safe_log_error("bulk_processing_job_failure", e, {
        session_id: session_id,
        total_files: total_files,
        processed_count: processed_count,
        failed_count: failed_files.size,
        total_duration: total_duration.round(3),
        job_id: job_id
      })
      
      logger.error "💀 Bulk processing job failed for session #{session_id}: #{e.message}"
      logger.error e.backtrace.join("\n")
      
      # Broadcast job failure
      ActionCable.server.broadcast("ragdoll_file_processing_#{session_id}", {
        type: 'job_error',
        error: e.message,
        status: 'failed'
      })
    end
  end
end