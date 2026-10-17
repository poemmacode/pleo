# Loads a crawl owned by the signed-in user and paginates its records by id (keyset).
module CrawlScoped
  extend ActiveSupport::Concern

  PAGE_SIZE = 50

  private
    def set_crawl
      @crawl = Crawl.joins(:project).where(projects: { user_id: Current.user.id }).find(params[:crawl_id] || params[:id])
    end

    # Returns [records, next_cursor]; pass ?after=<next_cursor> for the following page.
    def keyset(scope, size: PAGE_SIZE)
      scope = scope.where("#{scope.table_name}.id > ?", params[:after].to_i) if params[:after].present?
      records = scope.limit(size + 1).to_a
      more = records.size > size
      records = records.first(size)
      [ records, more ? records.last.id : nil ]
    end
end
