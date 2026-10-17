# Groups of indexable pages sharing a title or description, or with near-identical text.
class Crawls::DuplicatesController < ApplicationController
  include CrawlScoped

  TYPES = { "title" => "Títulos", "description" => "Descripciones", "content" => "Contenido" }.freeze
  MAX_GROUPS = 500

  before_action :set_crawl

  def index
    @type = TYPES.key?(params[:type]) ? params[:type] : "title"
    @groups = groups.sort_by { -_1.size }.first(MAX_GROUPS)
  end

  private
    def groups
      pages = @crawl.pages.where(indexable: true)
      case @type
      when "title" then pages.where.not(title_hash: nil).group_by(&:title_hash).values.select { _1.size > 1 }
      when "description" then pages.where.not(description_hash: nil).group_by(&:description_hash).values.select { _1.size > 1 }
      when "content"
        candidates = pages.where.not(text_simhash: nil).where(word_count: Audit::Checks::Content::NearDuplicate::MIN_WORDS..)
        by_id = candidates.index_by(&:id)
        Audit::NearDuplicates.groups(candidates.map { [ _1.id, _1.text_simhash ] }).map { |ids| ids.map { by_id[_1] } }
      end
    end
end
