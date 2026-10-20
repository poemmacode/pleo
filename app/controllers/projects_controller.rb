class ProjectsController < ApplicationController
  before_action :set_project, only: %i[show destroy]

  def index
    @projects = Current.user.projects.includes(:domains).order(:created_at)
    @project = Project.new
  end

  def show
    @domain = Domain.new
  end

  def create
    @project = Current.user.projects.new(params.require(:project).permit(:name))
    if @project.save
      redirect_to @project, notice: t("projects.flash.created")
    else
      @projects = Current.user.projects.includes(:domains).order(:created_at)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy!
    redirect_to root_path, notice: t("projects.flash.deleted"), status: :see_other
  end

  private
    def set_project
      @project = Current.user.projects.find(params[:id])
    end
end
