# Public landing page. Signed-in users go straight to their projects.
class HomeController < ApplicationController
  allow_unauthenticated_access

  def show
    redirect_to projects_path if authenticated?
  end
end
