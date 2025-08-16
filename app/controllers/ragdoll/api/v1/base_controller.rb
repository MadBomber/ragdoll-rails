# frozen_string_literal: true

module Ragdoll
  module Api
    module V1
      class BaseController < ActionController::API
        protect_from_forgery with: :null_session
        before_action :set_default_response_format
        
        private
        
        def set_default_response_format
          request.format = :json
        end
        
        def render_error(message, status = :unprocessable_entity)
          render json: { error: message }, status: status
        end
        
        def render_success(data = {}, message = nil)
          response = { success: true }
          response[:message] = message if message
          response[:data] = data unless data.empty?
          render json: response
        end
      end
    end
  end
end