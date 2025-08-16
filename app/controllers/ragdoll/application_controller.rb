# frozen_string_literal: true

module Ragdoll
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    before_action :set_current_user
    
    layout 'ragdoll/application'
    
    private
    
    def set_current_user
      # This can be overridden in the host application
      # to set the current user for the Ragdoll engine
    end
  end
end