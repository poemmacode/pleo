class CreateAuditTables < ActiveRecord::Migration[8.0]
  def change
    change_table :pages, bulk: true do |t|
      # On-page extraction (Crawling::PageExtractor)
      t.boolean :extracted, null: false, default: false
      t.text :title
      t.integer :title_count
      t.text :meta_description
      t.integer :meta_description_count
      t.string :meta_robots
      t.string :x_robots_tag
      t.boolean :noindex, null: false, default: false
      t.boolean :nofollow, null: false, default: false
      t.text :canonical_hrefs, array: true, null: false, default: []
      t.text :canonical # resolved + normalized, nil if missing or ambiguous
      t.boolean :indexable, null: false, default: false
      t.string :indexability_reason
      t.string :lang
      t.string :charset
      t.string :viewport
      t.jsonb :hreflang, null: false, default: []
      t.text :h1, array: true, null: false, default: []
      t.jsonb :headings, null: false, default: []
      t.integer :word_count
      t.bigint :text_simhash
      t.binary :title_hash
      t.binary :description_hash
      t.integer :images_count
      t.integer :images_missing_alt
      t.integer :mixed_content_count
      t.text :mixed_content_samples, array: true, null: false, default: []
      t.integer :links_count
      t.jsonb :open_graph, null: false, default: {}
      # Link graph (Audit::LinkGraph)
      t.integer :inlinks_count, null: false, default: 0
      t.integer :outlinks_internal, null: false, default: 0
      t.integer :outlinks_external, null: false, default: 0
      t.float :internal_pagerank
    end
    add_index :pages, [ :crawl_id, :title_hash ]
    add_index :pages, [ :crawl_id, :description_hash ]

    add_reference :links, :to_page, foreign_key: { to_table: :pages, on_delete: :nullify }, index: false

    create_table :page_structured_data do |t|
      t.references :page, null: false, foreign_key: { on_delete: :cascade }
      t.string :syntax, null: false # json-ld | microdata | rdfa
      t.string :types, array: true, null: false, default: []
      t.jsonb :data
      t.boolean :valid_syntax, null: false, default: true
      t.jsonb :validation_errors, null: false, default: []
      t.jsonb :validation_warnings, null: false, default: []
    end

    create_table :external_link_checks do |t|
      t.references :crawl, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.text :url, null: false
      t.binary :url_hash, null: false
      t.integer :status_code
      t.string :error
      t.datetime :checked_at, null: false
      t.index [ :crawl_id, :url_hash ], unique: true
    end

    create_table :check_definitions do |t|
      t.string :key, null: false, index: { unique: true }
      t.string :category, null: false
      t.string :severity, null: false # error | warning | notice
      t.integer :weight, null: false
      t.string :title, null: false
      t.text :description, null: false
      t.text :how_to_fix, null: false
      t.timestamps
    end

    create_table :issues do |t|
      t.references :crawl, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :check_key, null: false
      t.references :page, foreign_key: { on_delete: :cascade }, index: false
      t.text :url # for findings about URLs that have no page (e.g. blocked by robots.txt) or the site
      t.jsonb :details, null: false, default: {}
      t.float :priority_score
      t.index [ :crawl_id, :check_key ]
      t.index [ :crawl_id, :page_id ]
    end

    change_table :crawls, bulk: true do |t|
      t.string :audit_status, null: false, default: "pending" # pending | running | done | failed
      t.string :audit_error
      t.datetime :audited_at
      t.jsonb :site_facts, null: false, default: {} # llms.txt, AI bot access, etc.
    end
  end
end
