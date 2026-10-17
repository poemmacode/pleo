module CrawlScoped
  extend ActiveSupport::Concern

  MAX_LIMIT = 200

  private
    def set_crawl
      @crawl = Crawl.joins(:project).where(projects: { user_id: Current.user.id }).find(params[:crawl_id] || params[:id])
    end

    # Keyset pagination: ?after=<last id>&limit=
    def paginate(scope)
      limit = params.fetch(:limit, 50).to_i.clamp(1, MAX_LIMIT)
      scope = scope.where("#{scope.table_name}.id > ?", params[:after].to_i) if params[:after].present?
      records = scope.limit(limit + 1).to_a
      more = records.size > limit
      records = records.first(limit)
      render json: { data: records.map { yield _1 }, meta: { next_cursor: more ? records.last.id : nil } }
    end
end
