module Ragdoll
  class BulkUploadStatusChannel < ApplicationCable::Channel
    def subscribed
      session_id = params[:session_id]
      
      if session_id.present?
        stream_from "bulk_upload_status_#{session_id}"
        logger.info "📡 Client subscribed to bulk upload status for session: #{session_id}"
      else
        reject
        logger.warn "⚠️ Bulk upload status subscription rejected: missing session_id"
      end
    end

    def unsubscribed
      logger.info "📡 Client unsubscribed from bulk upload status"
    end

    def ping(data)
      # Respond to client ping to maintain connection
      transmit({
        type: 'pong',
        timestamp: Time.current.iso8601
      })
    end
  end
end