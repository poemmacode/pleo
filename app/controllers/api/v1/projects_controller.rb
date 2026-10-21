class Api::V1::ProjectsController < Api::V1::BaseController
  before_action :set_project, only: %i[show update destroy]

  def index
    projects = accessible_projects.includes(:domains).order(:id)
    records, next_cursor = keyset(projects)
    render json: { data: records.map { ApiSerializer.project(_1) }, next_cursor: }
  end

  def show
    render json: { data: ApiSerializer.project(@project) }
  end

  def create
    project = Current.user.projects.new(project_params)
    return render_validation_errors(project) unless project.save

    render json: { data: ApiSerializer.project(project) }, status: :created
  end

  def update
    return render_validation_errors(@project) unless @project.update(project_params)

    render json: { data: ApiSerializer.project(@project) }
  end

  def destroy
    return unless authorize_destroy!(@project)

    @project.destroy!
    head :no_content
  end

  private
    def set_project
      @project = accessible_projects.find(params[:id])
    end

    def project_params = params.require(:project).permit(:name)
end
