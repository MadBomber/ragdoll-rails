# frozen_string_literal: true

module Ragdoll
  class JobsController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:restart_workers, :destroy, :bulk_delete, :bulk_retry, :cancel_all_pending]
    
    def index
      @pending_jobs = SolidQueue::Job.where(finished_at: nil).order(created_at: :desc).limit(50)
      @completed_jobs = SolidQueue::Job.where.not(finished_at: nil).order(finished_at: :desc).limit(50)
      @failed_jobs = SolidQueue::FailedExecution.order(created_at: :desc).limit(50)
      
      @stats = {
        pending: SolidQueue::Job.where(finished_at: nil).count,
        completed: SolidQueue::Job.where.not(finished_at: nil).count,
        failed: SolidQueue::FailedExecution.count,
        total: SolidQueue::Job.count
      }
    end
    
    def show
      @job = SolidQueue::Job.find(params[:id])
    end
    
    def retry
      failed_execution = SolidQueue::FailedExecution.find(params[:id])
      failed_execution.retry
      redirect_to ragdoll.jobs_path, notice: 'Job retried successfully'
    rescue => e
      redirect_to ragdoll.jobs_path, alert: "Failed to retry job: #{e.message}"
    end
    
    def destroy
      if params[:type] == 'failed'
        SolidQueue::FailedExecution.find(params[:id]).destroy
      else
        SolidQueue::Job.find(params[:id]).destroy
      end
      redirect_to ragdoll.jobs_path, notice: 'Job deleted successfully'
    rescue => e
      redirect_to ragdoll.jobs_path, alert: "Failed to delete job: #{e.message}"
    end
    
    def health
      health_status = WorkerHealthService.check_worker_health
      render json: health_status
    end
    
    def restart_workers
      if WorkerHealthService.needs_restart?
        # Process stuck jobs first
        processed_count = WorkerHealthService.process_stuck_jobs!(10)
        
        # Restart workers
        WorkerHealthService.restart_workers!
        
        redirect_to ragdoll.jobs_path, notice: "Workers restarted! Processed #{processed_count} stuck jobs."
      else
        redirect_to ragdoll.jobs_path, alert: "Workers appear to be healthy."
      end
    rescue => e
      redirect_to ragdoll.jobs_path, alert: "Failed to restart workers: #{e.message}"
    end

    def bulk_delete
      job_ids = params[:job_ids] || []
      job_type = params[:job_type] || 'pending'
      
      deleted_count = 0
      
      job_ids.each do |job_id|
        begin
          if job_type == 'failed'
            SolidQueue::FailedExecution.find(job_id).destroy
          else
            SolidQueue::Job.find(job_id).destroy
          end
          deleted_count += 1
        rescue => e
          Rails.logger.error "Failed to delete job #{job_id}: #{e.message}"
        end
      end
      
      redirect_to ragdoll.jobs_path, notice: "Successfully deleted #{deleted_count} job(s)."
    rescue => e
      redirect_to ragdoll.jobs_path, alert: "Bulk delete failed: #{e.message}"
    end

    def bulk_retry
      job_ids = params[:job_ids] || []
      retried_count = 0
      
      job_ids.each do |job_id|
        begin
          failed_execution = SolidQueue::FailedExecution.find(job_id)
          failed_execution.retry
          retried_count += 1
        rescue => e
          Rails.logger.error "Failed to retry job #{job_id}: #{e.message}"
        end
      end
      
      redirect_to ragdoll.jobs_path, notice: "Successfully retried #{retried_count} job(s)."
    rescue => e
      redirect_to ragdoll.jobs_path, alert: "Bulk retry failed: #{e.message}"
    end

    def cancel_all_pending
      begin
        deleted_count = SolidQueue::Job.where(finished_at: nil).delete_all
        redirect_to ragdoll.jobs_path, notice: "Successfully canceled #{deleted_count} pending job(s)."
      rescue => e
        redirect_to ragdoll.jobs_path, alert: "Failed to cancel all pending jobs: #{e.message}"
      end
    end
  end
end