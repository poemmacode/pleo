module PageSerializer
  def self.call(page)
    page.slice(:id, :url, :depth, :in_sitemap, :status_code, :redirect_url, :fetch_error, :content_type,
               :content_length, :truncated, :response_ms, :fetched_at)
  end
end
