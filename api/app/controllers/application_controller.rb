class ApplicationController < ActionController::API
  include ActionController::Cookies
  include ActionController::RequestForgeryProtection
  include Authentication
  include ErrorRendering

  protect_from_forgery with: :exception
  # Framework config only reaches ActionController::Base, so honour config/environments/*.rb here.
  self.allow_forgery_protection = Rails.configuration.action_controller.allow_forgery_protection != false
end
