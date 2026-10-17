class Api::V1::ProjectsController < ApplicationController
  before_action :set_project, only: %i[show update destroy]

  def index
    projects = Current.user.projects.includes(:domains).order(:created_at)
    render json: { data: projects.map { ProjectSerializer.call(_1) } }
  end

  def show
    render json: { data: ProjectSerializer.call(@project) }
  end

  def create
    project = Current.user.projects.new(project_params)
    if project.save
      render status: :created, json: { data: ProjectSerializer.call(project) }
    else
      render_validation_errors(project)
    end
  end

  def update
    if @project.update(project_params)
      render json: { data: ProjectSerializer.call(@project) }
    else
      render_validation_errors(@project)
    end
  end

  def destroy
    @project.destroy!
    head :no_content
  end

  private
    def set_project
      @project = Current.user.projects.find(params[:id])
    end

    def project_params
      params.require(:project).permit(:name, :monthly_api_budget_cents)
    end
end
