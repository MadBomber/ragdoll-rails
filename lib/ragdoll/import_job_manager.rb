# This file defines the ImportJobManager class for managing and batching import jobs.

# frozen_string_literal: true

module Ragdoll
  class ImportJobManager
    def initialize(batch_size: 10)
      @batch_size = batch_size
      @job_queue = Queue.new
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
