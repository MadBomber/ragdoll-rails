# frozen_string_literal: true

module Ragdoll
  class DocumentsController < ApplicationController
    before_action :set_document, only: [:show, :edit, :update, :destroy, :preview, :reprocess, :download]
    skip_before_action :verify_authenticity_token, only: [:upload_async]
    
    def index
      @documents = ::Ragdoll::Document.all
      @documents = @documents.where(status: params[:status]) if params[:status].present?
      @documents = @documents.where(document_type: params[:document_type]) if params[:document_type].present?
      @documents = @documents.where('title ILIKE ?', "%#{params[:search]}%") if params[:search].present?
      @documents = @documents.order(created_at: :desc)
      
      @document_types = ::Ragdoll::Document.distinct.pluck(:document_type).compact
      @statuses = ::Ragdoll::Document.distinct.pluck(:status).compact
    end
    
    def show
      @embeddings = @document.all_embeddings
      # Load recent searches for sidebar
      @recent_searches = ::Ragdoll::Search.order(created_at: :desc).limit(10)
    end
    
    def new
      @document = ::Ragdoll::Document.new
    end
    
    def create
      if params[:ragdoll_document] && params[:ragdoll_document][:files].present?
        uploaded_files = params[:ragdoll_document][:files]
        force_duplicate = params[:ragdoll_document][:force_duplicate] == '1'
        @results = []
        
        # Ensure uploaded_files is always an array
        uploaded_files = [uploaded_files] unless uploaded_files.is_a?(Array)
        
        uploaded_files.each do |file|
          begin
            # Skip if file is not a valid upload object
            next unless file.respond_to?(:original_filename)
            
            # Save uploaded file temporarily
            temp_path = ::Rails.root.join('tmp', 'uploads', file.original_filename)
            FileUtils.mkdir_p(File.dirname(temp_path))
            File.binwrite(temp_path, file.read)
            
            # Use Ragdoll to add document with force option
            result = ::Ragdoll.add_document(path: temp_path.to_s, force: force_duplicate)
            
            # Get the actual document object if successful
            if result[:success] && result[:document_id]
              document = ::Ragdoll::Document.find(result[:document_id])
              duplicate_detected = result[:duplicate] || (result[:message] && result[:message].include?('already exists'))
              @results << { 
                file: file.original_filename, 
                success: true, 
                document: document, 
                message: result[:message],
                duplicate: duplicate_detected,
                forced: force_duplicate
              }
            else
              @results << { file: file.original_filename, success: false, error: result[:error] || "Unknown error" }
            end
            
            # Clean up temp file
            File.delete(temp_path) if File.exist?(temp_path)
          rescue => e
            filename = file.respond_to?(:original_filename) ? file.original_filename : file.to_s
            @results << { file: filename, success: false, error: e.message }
          end
        end
        
        render :upload_results
      elsif params[:ragdoll_document] && params[:ragdoll_document][:text_content].present?
        begin
          force_duplicate = params[:ragdoll_document][:force_duplicate] == '1'
          
          # For text content, we need to save it as a file first since Ragdoll.add_document expects a file
          temp_path = ::Rails.root.join('tmp', 'uploads', "#{SecureRandom.hex(8)}.txt")
          FileUtils.mkdir_p(File.dirname(temp_path))
          File.write(temp_path, params[:ragdoll_document][:text_content])
          
          result = ::Ragdoll.add_document(path: temp_path.to_s, force: force_duplicate)
          
          # Clean up temp file
          File.delete(temp_path) if File.exist?(temp_path)
          
          if result[:success] && result[:document_id]
            document = ::Ragdoll::Document.find(result[:document_id])
            duplicate_detected = result[:duplicate] || (result[:message] && result[:message].include?('already exists'))
            
            if duplicate_detected && !force_duplicate
              redirect_to ragdoll.document_path(document), notice: 'Document already exists - returned existing document.'
            elsif duplicate_detected && force_duplicate
              redirect_to ragdoll.document_path(document), notice: 'Document was successfully created (duplicate forced).'
            else
              redirect_to ragdoll.document_path(document), notice: 'Document was successfully created.'
            end
          else
            @document = ::Ragdoll::Document.new
            @document.errors.add(:base, result[:error] || "Unknown error occurred")
            render :new
          end
        rescue => e
          @document = ::Ragdoll::Document.new
          @document.errors.add(:base, e.message)
          render :new
        end
      else
        @document = ::Ragdoll::Document.new
        @document.errors.add(:base, "Please provide either files or text content")
        render :new
      end
    end
    
    def edit
    end
    
    def update
      if @document.update(document_params)
        redirect_to ragdoll.document_path(@document), notice: 'Document was successfully updated.'
      else
        render :edit
      end
    end
    
    def destroy
      @document.destroy
      redirect_to ragdoll.documents_url, notice: 'Document was successfully deleted.'
    end
    
    def preview
      respond_to do |format|
        format.html { render layout: false }
        format.json { render json: { content: @document.content, metadata: @document.metadata } }
      end
    end
    
    def reprocess
      begin
        # Delete existing embeddings
        @document.all_embeddings.destroy_all
        
        # Reprocess document
        @document.update(status: 'pending')
        
        # Process embeddings in background
        ::Ragdoll::GenerateEmbeddingsJob.perform_later(@document.id)
        
        redirect_to ragdoll.document_path(@document), notice: 'Document reprocessing initiated.'
      rescue => e
        redirect_to ragdoll.document_path(@document), alert: "Error reprocessing document: #{e.message}"
      end
    end
    
    def download
      if @document.location.present? && File.exist?(@document.location)
        send_file @document.location, filename: @document.title
      else
        redirect_to ragdoll.document_path(@document), alert: 'File not found.'
      end
    end
    
    def bulk_upload
      Rails.logger.debug "🔍 Bulk upload params: #{params.inspect}"
      Rails.logger.debug "🔍 Directory files param: #{params[:directory_files].inspect}"
      Rails.logger.debug "🔍 Directory files class: #{params[:directory_files].class}"
      
      if params[:directory_files].present?
        begin
          # Filter out empty strings that Rails includes in file arrays
          files = params[:directory_files].reject(&:blank?)
          Rails.logger.debug "🔍 Files array after filtering: #{files.inspect}"
          Rails.logger.debug "🔍 First file class: #{files.first.class if files.respond_to?(:first)}"
          
          if files.empty?
            flash[:alert] = "No valid files selected for upload."
            redirect_to ragdoll.documents_path
            return
          end
          
          successful_count = 0
          failed_files = []
          
          # Process files in batches to avoid "too many open files" error
          batch_size = 50  # Process 50 files at a time
          files.each_slice(batch_size) do |file_batch|
            file_batch.each do |file|
              begin
                # Create a temporary file to save the uploaded content
                temp_file = Tempfile.new([File.basename(file.original_filename, ".*"), File.extname(file.original_filename)])
                
                # Handle encoding issues by reading as binary first
                content = file.read
                if content.encoding == Encoding::ASCII_8BIT
                  # Try to force UTF-8 encoding, replacing invalid characters
                  content = content.force_encoding('UTF-8')
                  unless content.valid_encoding?
                    content = content.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
                  end
                end
                
                temp_file.write(content)
                temp_file.close
                
                # Add document using ragdoll with force option if provided
                force_duplicate = params[:force_duplicate] == '1'
                result = ::Ragdoll.add_document(path: temp_file.path, force: force_duplicate)
                
                if result
                  successful_count += 1
                else
                  failed_files << file.original_filename
                end
                
              rescue => e
                Rails.logger.error "Failed to process file #{file.original_filename}: #{e.message}"
                failed_files << file.original_filename
              ensure
                # Clean up temp file
                temp_file&.unlink if temp_file&.path
              end
            end
            
            # Force garbage collection after each batch to free file descriptors
            GC.start
          end
          
          if failed_files.any?
            flash[:alert] = "Processed #{successful_count}/#{files.count} files. Failed: #{failed_files.join(', ')}"
          else
            flash[:notice] = "Successfully processed #{successful_count} files from directory."
          end
          
        rescue => e
          Rails.logger.error "Bulk upload error: #{e.message}"
          flash[:alert] = "Error processing directory: #{e.message}"
        end
      else
        flash[:alert] = "No files selected for upload."
      end
      
      redirect_to ragdoll.documents_path
    end
    
    def bulk_delete
      if params[:document_ids].present?
        documents = ::Ragdoll::Document.where(id: params[:document_ids])
        count = documents.count
        documents.destroy_all
        flash[:notice] = "Successfully deleted #{count} documents."
      else
        flash[:alert] = "No documents selected for deletion."
      end
      
      redirect_to ragdoll.documents_path
    end
    
    def bulk_reprocess
      if params[:document_ids].present?
        documents = ::Ragdoll::Document.where(id: params[:document_ids])
        documents.each do |document|
          document.all_embeddings.destroy_all
          document.update(status: 'pending')
          ::Ragdoll::GenerateEmbeddingsJob.perform_later(document.id)
        end
        flash[:notice] = "Reprocessing initiated for #{documents.count} documents."
      else
        flash[:alert] = "No documents selected for reprocessing."
      end
      
      redirect_to ragdoll.documents_path
    end

    def upload_async
      logger.info "upload_async called with params: #{params.inspect}"
      logger.info "Session ID: #{session.id}"
      logger.info "Request ID: #{request.request_id}"
      logger.info "Temp Session ID: #{params[:temp_session_id]}"
      
      if params[:ragdoll_document] && params[:ragdoll_document][:files].present?
        # Priority: temp_session_id from frontend, then session ID, then request ID as fallback
        session_id = if params[:temp_session_id].present?
                       params[:temp_session_id]
                     elsif session.id.present?
                       session.id.to_s
                     else
                       request.request_id
                     end
        logger.info "Using session_id: #{session_id} (source: #{params[:temp_session_id].present? ? 'temp_session_id' : session.id.present? ? 'session' : 'request'})"
        uploaded_files = params[:ragdoll_document][:files]
        
        logger.info "Files received: #{uploaded_files.inspect}"
        
        # Ensure uploaded_files is always an array
        uploaded_files = [uploaded_files] unless uploaded_files.is_a?(Array)
        
        # Log file analysis for debugging count discrepancies
        total_files = uploaded_files.count
        valid_files = uploaded_files.select { |f| f && f.respond_to?(:original_filename) && f.original_filename.present? }
        filtered_count = total_files - valid_files.count
        
        logger.info "📊 File upload analysis:"
        logger.info "   Total files in upload array: #{total_files}"
        logger.info "   Valid files with original_filename: #{valid_files.count}"
        logger.info "   Files filtered out: #{filtered_count}"
        
        if filtered_count > 0
          uploaded_files.each_with_index do |file, index|
            unless file && file.respond_to?(:original_filename) && file.original_filename.present?
              logger.warn "   Filtered file #{index + 1}: #{file.class} - #{file.inspect}"
            end
          end
        end
        
        processed_count = 0
        results = []
        
        # Process files in batches to avoid "too many open files" error
        batch_size = 50  # Process 50 files at a time
        uploaded_files.each_slice(batch_size).with_index do |file_batch, batch_index|
          file_batch.each_with_index do |file, batch_file_index|
            index = batch_index * batch_size + batch_file_index
          next unless file.respond_to?(:original_filename)
          
          logger.info "Processing file #{index + 1}: #{file.original_filename}"
          
          begin
            # Generate unique file ID
            file_id = "#{session_id}_#{index}_#{Time.current.to_i}"
            
            # Save uploaded file temporarily
            temp_path = ::Rails.root.join('tmp', 'uploads', "#{file_id}_#{file.original_filename}")
            FileUtils.mkdir_p(File.dirname(temp_path))
            File.binwrite(temp_path, file.read)
            
            logger.info "File saved to: #{temp_path}"
            
            # Try to queue background job first, fallback to direct processing
            begin
              if defined?(::Ragdoll::ProcessFileJob)
                ::Ragdoll::ProcessFileJob.perform_later(file_id, session_id, file.original_filename, temp_path.to_s)
                logger.info "Job queued for file: #{file_id}"
                results << { file: file.original_filename, status: 'queued' }
              else
                raise "ProcessFileJob not available"
              end
            rescue => job_error
              logger.warn "Background job failed, processing directly: #{job_error.message}"
              
              # Process directly if job system is not available  
              force_duplicate = params[:ragdoll_document][:force_duplicate] == '1'
              result = ::Ragdoll.add_document(path: temp_path.to_s, force: force_duplicate)
              
              if result[:success] && result[:document_id]
                document = ::Ragdoll::Document.find(result[:document_id])
                results << { 
                  file: file.original_filename, 
                  status: 'completed_sync',
                  document_id: document.id
                }
                logger.info "File processed synchronously: #{file.original_filename}"
              else
                results << { 
                  file: file.original_filename, 
                  status: 'failed',
                  error: result[:error] || 'Unknown error'
                }
              end
              
              # Clean up temp file for sync processing
              File.delete(temp_path) if File.exist?(temp_path)
            end
            
            processed_count += 1
          rescue => file_error
            logger.error "Error processing file #{file.original_filename}: #{file_error.message}"
            results << { 
              file: file.original_filename, 
              status: 'failed',
              error: file_error.message
            }
          end
          end
          
          # Force garbage collection after each batch to free file descriptors
          GC.start
        end
        
        logger.info "Returning success response for #{processed_count} files"
        render json: { 
          success: true, 
          session_id: session_id,
          results: results,
          message: "#{processed_count} file(s) processed" 
        }
      else
        logger.error "No files provided in upload_async"
        render json: { success: false, error: "No files provided" }, status: :bad_request
      end
    rescue => e
      logger.error "Error in upload_async: #{e.message}"
      logger.error e.backtrace.join("\n")
      render json: { success: false, error: e.message }, status: :internal_server_error
    end
    
    def status
      @processing_stats = {
        pending: ::Ragdoll::Document.where(status: 'pending').count,
        processing: ::Ragdoll::Document.where(status: 'processing').count,
        processed: ::Ragdoll::Document.where(status: 'processed').count,
        failed: ::Ragdoll::Document.where(status: 'failed').count
      }
      
      @recent_activity = ::Ragdoll::Document.order(updated_at: :desc).limit(20)
      
      respond_to do |format|
        format.html
        format.json { render json: @processing_stats }
      end
    end
    
    private
    
    def set_document
      @document = ::Ragdoll::Document.find(params[:id])
    end
    
    def document_params
      params.require(:ragdoll_document).permit(:title, :content, :metadata, :status, :text_content, :force_duplicate, files: [])
    end
  end
end