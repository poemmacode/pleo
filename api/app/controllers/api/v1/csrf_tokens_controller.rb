class Api::V1::CsrfTokensController < ApplicationController
  allow_unauthenticated_access

  def show
    render json: { data: { token: form_authenticity_token } }
  end
end
