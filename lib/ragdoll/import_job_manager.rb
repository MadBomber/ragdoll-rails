# This file defines the ImportJobManager class for managing and batching import jobs.

# frozen_string_literal: true

module Ragdoll
  class ImportJobManager
    def initialize(batch_size: 10)
      @batch_size = batch_size
      @job_queue = Queue.new
      @running_jobs = []
    end

    Job = Struct.new(:id, :name, :type, :recursive)

    def start_job(job, *args)
      job_instance = job.perform_later(*args)
      job_name = args.first
      job_type = File.directory?(job_name) ? :directory : :file
      recursive = args.last[:recursive] if job_type == :directory
      @running_jobs << Job.new(job_instance.job_id, job_name, job_type, recursive)
    end

    def stop_job(job_id)
      job = @running_jobs.find { |j| j.job_id == job_id }
      job&.cancel
      @running_jobs.delete(job)
    end

    def pause_job(job_id)
      job = @running_jobs.find { |j| j.job_id == job_id }
      job&.pause
    end

    def resume_job(job_id)
      job = @running_jobs.find { |j| j.job_id == job_id }
      job&.resume
    end

    def running_jobs
      @running_jobs
    end

    def waiting_jobs
      @job_queue.size
    end

    def enqueue(job, *args)
      @job_queue << [job, args]
    end

    def process_jobs
      until @job_queue.empty?
        batch = []
        @batch_size.times do
          break if @job_queue.empty?

          batch << @job_queue.pop
        end

        batch.each do |job, args|
          job.perform_later(*args)
        end
      end
    end
  end
end
