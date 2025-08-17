# frozen_string_literal: true

module Ragdoll
  class WorkerHealthService
    class << self
      def check_worker_health
        {
          status: 'healthy',
          workers: worker_status,
          queues: queue_status,
          timestamp: Time.current
        }
      rescue => e
        {
          status: 'error',
          error: e.message,
          timestamp: Time.current
        }
      end

      def needs_restart?
        # Check if there are stuck jobs or workers
        stuck_jobs_count > 5 || !workers_running?
      rescue
        false
      end

      def process_stuck_jobs!(limit = 10)
        processed = 0
        
        # Find jobs that have been processing for too long (e.g., > 1 hour)
        if defined?(SolidQueue::Job)
          stuck_jobs = SolidQueue::Job
            .where(finished_at: nil)
            .where('created_at < ?', 1.hour.ago)
            .limit(limit)
          
          stuck_jobs.each do |job|
            job.update(finished_at: Time.current)
            processed += 1
          end
        end
        
        processed
      rescue => e
        ::Rails.logger.error "Failed to process stuck jobs: #{e.message}"
        0
      end

      def restart_workers!
        # In development, we typically don't restart workers
        # This would be implemented differently in production
        ::Rails.logger.info "Worker restart requested (no-op in development)"
        true
      rescue => e
        ::Rails.logger.error "Failed to restart workers: #{e.message}"
        false
      end

      private

      def worker_status
        if defined?(SolidQueue::Worker)
          {
            count: SolidQueue::Worker.count,
            active: SolidQueue::Worker.where('last_heartbeat_at > ?', 5.minutes.ago).count
          }
        else
          { count: 0, active: 0 }
        end
      rescue
        { count: 0, active: 0, error: 'Unable to check worker status' }
      end

      def queue_status
        if defined?(SolidQueue::Job)
          {
            pending: SolidQueue::Job.where(finished_at: nil).count,
            completed: SolidQueue::Job.where.not(finished_at: nil).count,
            failed: defined?(SolidQueue::FailedExecution) ? SolidQueue::FailedExecution.count : 0
          }
        else
          { pending: 0, completed: 0, failed: 0 }
        end
      rescue
        { pending: 0, completed: 0, failed: 0, error: 'Unable to check queue status' }
      end

      def stuck_jobs_count
        return 0 unless defined?(SolidQueue::Job)
        
        SolidQueue::Job
          .where(finished_at: nil)
          .where('created_at < ?', 1.hour.ago)
          .count
      rescue
        0
      end

      def workers_running?
        return false unless defined?(SolidQueue::Worker)
        
        SolidQueue::Worker
          .where('last_heartbeat_at > ?', 5.minutes.ago)
          .exists?
      rescue
        true # Assume workers are running if we can't check
      end
    end
  end
end