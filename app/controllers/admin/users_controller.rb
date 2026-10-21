# Admin-only list of accounts. The admin account itself cannot be deleted here: it comes from ADMIN_EMAIL.
class Admin::UsersController < ApplicationController
  before_action :require_admin!

  def index
    @users = User.order(:created_at).to_a
    @project_counts = Project.group(:user_id).count
  end

  def destroy
    user = User.find(params[:id])
    return redirect_to admin_users_path, alert: t("admin.users.flash.cannot_delete_admin"), status: :see_other if user.admin?

    user.destroy!
    redirect_to admin_users_path, notice: t("admin.users.flash.deleted", email: user.email), status: :see_other
  end
end
