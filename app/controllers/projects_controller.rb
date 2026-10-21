class ProjectsController < ApplicationController
  before_action :set_project, only: %i[show update destroy]

  def index
    @projects = projects_list
    @project = Project.new
  end

  def show
    @domain = Domain.new
  end

  def create
    @project = Current.user.projects.new(project_params)
    if @project.save
      redirect_to @project, notice: t("projects.flash.created")
    else
      @projects = projects_list
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: t("projects.flash.renamed"), status: :see_other
    else
      @domain = Domain.new
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    authorize_destroy!(@project)
    @project.destroy!
    redirect_to projects_path, notice: t("projects.flash.deleted"), status: :see_other
  end

  private
    def set_project
      @project = Current.user.accessible_projects.find(params[:id])
    end

    def project_params = params.require(:project).permit(:name)

    def projects_list
      Current.user.accessible_projects.includes(:domains, :user).order(:created_at)
    end
end
