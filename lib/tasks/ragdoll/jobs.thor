# frozen_string_literal: true

require 'thor'

module Ragdoll
  class Jobs < Thor
    desc "jobs [JOB_ID]", "Report the status of all running and queued import jobs, or a specific job if JOB_ID is provided"
    method_option :stop_all, type: :boolean, default: false, desc: "Stop all running and queued jobs"
    method_option :pause_all, type: :boolean, default: false, desc: "Pause all running jobs"
    method_option :resume_all, type: :boolean, default: false, desc: "Resume all paused jobs"
    method_option :stop, type: :boolean, default: false, desc: "Stop a specific job"
    method_option :pause, type: :boolean, default: false, desc: "Pause a specific job"
    method_option :resume, type: :boolean, default: false, desc: "Resume a specific job"
    def jobs(job_id = nil)
      job_manager = Ragdoll::ImportJobManager.new

      if job_id
        if options[:stop]
          job_manager.stop_job(job_id)
          puts "Stopped job ID: #{job_id}."
        elsif options[:pause]
          job_manager.pause_job(job_id)
          puts "Paused job ID: #{job_id}."
        elsif options[:resume]
          job_manager.resume_job(job_id)
          puts "Resumed job ID: #{job_id}."
        else
          puts "Fetching status for job ID: #{job_id}..."
        end
      else
        if options[:stop_all]
          job_manager.running_jobs.each { |job| job_manager.stop_job(job.job_id) }
          puts "Stopped all jobs."
        elsif options[:pause_all]
          job_manager.running_jobs.each { |job| job_manager.pause_job(job.job_id) }
          puts "Paused all running jobs."
        elsif options[:resume_all]
          job_manager.running_jobs.each { |job| job_manager.resume_job(job.job_id) }
          puts "Resumed all paused jobs."
        else
          puts "Fetching status of all running and queued import jobs..."
          puts "Running Jobs: #{job_manager.running_jobs.count}"
          puts "Waiting Jobs: #{job_manager.waiting_jobs}"
        end
      end
      if job_id
        if options[:stop]
          puts "Stopping job ID: #{job_id}..."
        elsif options[:pause]
          puts "Pausing job ID: #{job_id}..."
        elsif options[:resume]
          puts "Resuming job ID: #{job_id}..."
        else
          puts "Fetching status for job ID: #{job_id}..."
        end
      else
        if options[:stop_all]
          puts "Stopping all jobs..."
        elsif options[:pause_all]
          puts "Pausing all running jobs..."
        elsif options[:resume_all]
          puts "Resuming all paused jobs..."
        else
          puts "Fetching status of all running and queued import jobs..."
          job_manager.running_jobs.each do |job|
            puts "Job ID: #{job.id}, Name: #{job.name}, Type: #{job.type}, Recursive: #{job.recursive}"
          end
        end
      end
    end
  end
end
