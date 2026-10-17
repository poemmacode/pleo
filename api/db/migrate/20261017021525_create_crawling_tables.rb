class CreateCrawlingTables < ActiveRecord::Migration[8.0]
  def change
    create_table :crawls do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }
      t.references :domain, null: false, foreign_key: { on_delete: :cascade }
      t.string :status, null: false, default: "queued"
      t.string :status_reason
      t.jsonb :config, null: false, default: {}
      t.float :current_rps, null: false
      t.jsonb :adaptive_rate, null: false, default: {}
      t.string :sitemap_status, null: false, default: "pending" # pending | done | skipped
      t.jsonb :sitemaps, null: false, default: []
      t.integer :sitemap_urls_out_of_scope, null: false, default: 0
      t.integer :pages_discovered, null: false, default: 0
      t.integer :pages_claimed, null: false, default: 0
      t.integer :pages_crawled, null: false, default: 0
      t.integer :pages_failed, null: false, default: 0
      t.integer :pages_skipped, null: false, default: 0
      t.datetime :terms_accepted_at
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
      t.index [ :domain_id, :status ]
    end

    # robots.txt is per host: a "domain" scope can span several subdomains.
    create_table :crawl_hosts do |t|
      t.references :crawl, null: false, foreign_key: { on_delete: :cascade }
      t.string :host, null: false
      t.string :robots_outcome, null: false # parsed | unavailable | unreachable
      t.integer :robots_status
      t.text :robots_txt
      t.float :crawl_delay
      t.jsonb :sitemaps, null: false, default: []
      t.datetime :fetched_at, null: false
      t.index [ :crawl_id, :host ], unique: true
    end

    create_table :crawl_urls do |t|
      t.references :crawl, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.text :url, null: false
      t.binary :url_hash, null: false
      t.integer :depth # null when only known from a sitemap
      t.string :source, null: false # seed | sitemap | link | redirect
      t.boolean :in_sitemap, null: false, default: false
      t.string :state, null: false, default: "pending" # pending | fetching | done | skipped
      t.string :skip_reason # robots | limit | unsafe_host | out_of_scope | excluded | error
      t.integer :attempts, null: false, default: 0
      t.datetime :claimed_at
      t.index [ :crawl_id, :url_hash ], unique: true
      t.index [ :crawl_id, :state, :depth, :id ]
    end

    create_table :pages do |t|
      t.references :crawl, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :crawl_url, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.text :url, null: false
      t.integer :depth
      t.boolean :in_sitemap, null: false, default: false
      t.integer :status_code
      t.text :redirect_url
      t.string :fetch_error
      t.string :content_type
      t.integer :content_length
      t.boolean :truncated, null: false, default: false
      t.integer :response_ms
      t.string :ip
      t.jsonb :headers, null: false, default: {}
      t.datetime :fetched_at, null: false
      t.index [ :crawl_id, :status_code ]
      t.index [ :crawl_id, :id ]
    end

    # Raw HTML kept so audit checks can be re-run without re-fetching (gzip-compressed).
    create_table :page_bodies, id: false do |t|
      t.references :page, null: false, primary_key: true, foreign_key: { on_delete: :cascade }, index: false
      t.binary :body_gzip, null: false
    end

    create_table :links do |t|
      t.references :crawl, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :from_page, null: false, foreign_key: { to_table: :pages, on_delete: :cascade }
      t.text :to_url, null: false
      t.binary :to_url_hash, null: false
      t.boolean :internal, null: false
      t.text :anchor
      t.string :rel, array: true, null: false, default: []
      t.index [ :crawl_id, :to_url_hash ]
    end
  end
end
