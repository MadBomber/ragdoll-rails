# frozen_string_literal: true

module Ragdoll
  class FileProcessingChannel < ApplicationCable::Channel
    def subscribed
      stream_from "ragdoll_file_processing_#{params[:session_id]}"
      puts "📡 Ragdoll::FileProcessingChannel subscribed to ragdoll_file_processing_#{params[:session_id]}"
      logger.info "📡 Ragdoll::FileProcessingChannel subscribed to ragdoll_file_processing_#{params[:session_id]}"
    end

    def unsubscribed
      puts "📡 Ragdoll::FileProcessingChannel unsubscribed from ragdoll_file_processing_#{params[:session_id]}"
      logger.info "📡 Ragdoll::FileProcessingChannel unsubscribed from ragdoll_file_processing_#{params[:session_id]}"
    end
    
    def test_connection
      puts "🏓 Received test_connection ping from session: #{params[:session_id]}"
      logger.info "🏓 Received test_connection ping from session: #{params[:session_id]}"
      ActionCable.server.broadcast("ragdoll_file_processing_#{params[:session_id]}", {
        type: 'ping',
        message: 'Connection test successful',
        timestamp: Time.current.to_f
      })
    end
  end
end