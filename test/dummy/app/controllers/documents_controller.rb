require 'tempfile'

class DocumentsController < ApplicationController
  before_action :set_document, only: [:show, :edit, :update, :destroy, :preview, :reprocess, :download]
  
  def index
    @documents = Ragdoll::Document.all
    @documents = @documents.where(status: params[:status]) if params[:status].present?
    @documents = @documents.where(document_type: params[:document_type]) if params[:document_type].present?
    @documents = @documents.where('title ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    @documents = @documents.includes(:text_embeddings).order(created_at: :desc)
    
    @document_types = Ragdoll::Document.distinct.pluck(:document_type).compact
    @statuses = Ragdoll::Document.distinct.pluck(:status).compact
  end
  
  def show
    @embeddings = @document.text_embeddings.order(created_at: :desc)
    @recent_searches = Ragdoll::Search.order(created_at: :desc).limit(10)
  end
  
  def new
    @document = Ragdoll::Document.new
  end
  
  def create
    if params[:document][:files].present?
      uploaded_files = params[:document][:files]
      @results = []
      
      uploaded_files.each do |file|
        begin
          # Save uploaded file temporarily
          temp_path = Rails.root.join('tmp', 'uploads', file.original_filename)
          FileUtils.mkdir_p(File.dirname(temp_path))
          File.binwrite(temp_path, file.read)
          
          # Use Ragdoll high-level API to add document
          result = Ragdoll.add_document(path: temp_path.to_s)
          
          if result[:success]
            document = Ragdoll::Document.find(result[:document_id])
            # Update metadata
            document.update!(metadata: {
              original_filename: file.original_filename,
              content_type: file.content_type,
              size: file.size
            })
            @results << { file: file.original_filename, success: true, document: document }
          else
            @results << { file: file.original_filename, success: false, error: result[:error] }
          end
          
          # Clean up temp file
          File.delete(temp_path) if File.exist?(temp_path)
        rescue => e
          @results << { file: file.original_filename, success: false, error: e.message }
        end
      end
      
      render :upload_results
    elsif params[:document][:text_content].present?
      begin
        # Handle text content by creating a temporary file
        temp_file = Tempfile.new(['text_content', '.txt'])
        temp_file.write(params[:document][:text_content])
        temp_file.rewind
        
        begin
          result = Ragdoll.add_document(path: temp_file.path)
          
          if result[:success]
            @document = Ragdoll::Document.find(result[:document_id])
            # Update title and metadata if provided
            updates = {}
            updates[:title] = params[:document][:title] || "Text Document" if params[:document][:title].present? || @document.title.blank?
            updates[:metadata] = params[:document][:metadata] if params[:document][:metadata].present?
            @document.update!(updates) if updates.any?
          else
            raise result[:error] || "Failed to add document"
          end
        ensure
          temp_file.close
          temp_file.unlink
        end
        redirect_to @document, notice: 'Document was successfully created.'
      rescue => e
        @document = Ragdoll::Document.new
        @document.errors.add(:base, e.message)
        render :new
      end
    else
      @document = Ragdoll::Document.new
      @document.errors.add(:base, "Please provide either files or text content")
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @document.update(document_params)
      redirect_to @document, notice: 'Document was successfully updated.'
    else
      render :edit
    end
  end
  
  def destroy
    @document.destroy
    redirect_to documents_url, notice: 'Document was successfully deleted.'
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
      @document.text_embeddings.destroy_all
      
      # Reprocess document
      @document.update(status: 'pending')
      
      # Process embeddings in background
      Ragdoll::GenerateEmbeddingsJob.perform_later(@document.id)
      
      redirect_to @document, notice: 'Document reprocessing initiated.'
    rescue => e
      redirect_to @document, alert: "Error reprocessing document: #{e.message}"
    end
  end
  
  def download
    if @document.location.present? && File.exist?(@document.location)
      send_file @document.location, filename: @document.title
    else
      redirect_to @document, alert: 'File not found.'
    end
  end
  
  def bulk_upload
    if params[:directory_path].present?
      begin
        results = Ragdoll.add_directory(path: params[:directory_path])
        flash[:notice] = "Successfully processed #{results.count} files from directory."
      rescue => e
        flash[:alert] = "Error processing directory: #{e.message}"
      end
    end
    
    redirect_to documents_path
  end
  
  def bulk_delete
    if params[:document_ids].present?
      documents = Ragdoll::Document.where(id: params[:document_ids])
      count = documents.count
      documents.destroy_all
      flash[:notice] = "Successfully deleted #{count} documents."
    else
      flash[:alert] = "No documents selected for deletion."
    end
    
    redirect_to documents_path
  end
  
  def bulk_reprocess
    if params[:document_ids].present?
      documents = Ragdoll::Document.where(id: params[:document_ids])
      documents.each do |document|
        document.text_embeddings.destroy_all
        document.update(status: 'pending')
        Ragdoll::GenerateEmbeddingsJob.perform_later(document.id)
      end
      flash[:notice] = "Reprocessing initiated for #{documents.count} documents."
    else
      flash[:alert] = "No documents selected for reprocessing."
    end
    
    redirect_to documents_path
  end
  
  def status
    @processing_stats = {
      pending: Ragdoll::Document.where(status: 'pending').count,
      processing: Ragdoll::Document.where(status: 'processing').count,
      processed: Ragdoll::Document.where(status: 'processed').count,
      failed: Ragdoll::Document.where(status: 'failed').count
    }
    
    @recent_activity = Ragdoll::Document.order(updated_at: :desc).limit(20)
    
    respond_to do |format|
      format.html
      format.json { render json: @processing_stats }
    end
  end
  
  private
  
  def set_document
    @document = Ragdoll::Document.find(params[:id])
  end
  
  def document_params
    params.require(:document).permit(:title, :content, :metadata, :status)
  end
end