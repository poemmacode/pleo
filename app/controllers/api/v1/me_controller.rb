class Api::V1::MeController < Api::V1::BaseController
  def show
    render json: { data: ApiSerializer.user(Current.user) }
  end
end
