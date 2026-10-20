# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_10_20_051854) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "check_definitions", force: :cascade do |t|
    t.string "key", null: false
    t.string "category", null: false
    t.string "severity", null: false
    t.integer "weight", null: false
    t.string "title", null: false
    t.text "description", null: false
    t.text "how_to_fix", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_check_definitions_on_key", unique: true
  end

  create_table "crawl_hosts", force: :cascade do |t|
    t.bigint "crawl_id", null: false
    t.string "host", null: false
    t.string "robots_outcome", null: false
    t.integer "robots_status"
    t.text "robots_txt"
    t.float "crawl_delay"
    t.jsonb "sitemaps", default: [], null: false
    t.datetime "fetched_at", null: false
    t.index ["crawl_id", "host"], name: "index_crawl_hosts_on_crawl_id_and_host", unique: true
    t.index ["crawl_id"], name: "index_crawl_hosts_on_crawl_id"
  end

  create_table "crawl_urls", force: :cascade do |t|
    t.bigint "crawl_id", null: false
    t.text "url", null: false
    t.binary "url_hash", null: false
    t.integer "depth"
    t.string "source", null: false
    t.boolean "in_sitemap", default: false, null: false
    t.string "state", default: "pending", null: false
    t.string "skip_reason"
    t.integer "attempts", default: 0, null: false
    t.datetime "claimed_at"
    t.index ["crawl_id", "state", "depth", "id"], name: "index_crawl_urls_on_crawl_id_and_state_and_depth_and_id"
    t.index ["crawl_id", "url_hash"], name: "index_crawl_urls_on_crawl_id_and_url_hash", unique: true
  end

  create_table "crawls", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "domain_id", null: false
    t.string "status", default: "queued", null: false
    t.string "status_reason"
    t.jsonb "config", default: {}, null: false
    t.float "current_rps", null: false
    t.jsonb "adaptive_rate", default: {}, null: false
    t.string "sitemap_status", default: "pending", null: false
    t.jsonb "sitemaps", default: [], null: false
    t.integer "sitemap_urls_out_of_scope", default: 0, null: false
    t.integer "pages_discovered", default: 0, null: false
    t.integer "pages_claimed", default: 0, null: false
    t.integer "pages_crawled", default: 0, null: false
    t.integer "pages_failed", default: 0, null: false
    t.integer "pages_skipped", default: 0, null: false
    t.datetime "terms_accepted_at"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "audit_status", default: "pending", null: false
    t.string "audit_error"
    t.datetime "audited_at"
    t.jsonb "site_facts", default: {}, null: false
    t.float "health_score"
    t.jsonb "category_scores", default: {}, null: false
    t.string "performance_status"
    t.index ["domain_id", "status"], name: "index_crawls_on_domain_id_and_status"
    t.index ["domain_id"], name: "index_crawls_on_domain_id"
    t.index ["project_id"], name: "index_crawls_on_project_id"
  end

  create_table "domains", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "host", null: false
    t.string "verification_token", null: false
    t.string "verification_method"
    t.datetime "verified_at"
    t.datetime "last_verification_attempt_at"
    t.string "last_verification_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "host"], name: "index_domains_on_project_id_and_host", unique: true
    t.index ["project_id"], name: "index_domains_on_project_id"
  end

  create_table "external_link_checks", force: :cascade do |t|
    t.bigint "crawl_id", null: false
    t.text "url", null: false
    t.binary "url_hash", null: false
    t.integer "status_code"
    t.string "error"
    t.datetime "checked_at", null: false
    t.index ["crawl_id", "url_hash"], name: "index_external_link_checks_on_crawl_id_and_url_hash", unique: true
  end

  create_table "issues", force: :cascade do |t|
    t.bigint "crawl_id", null: false
    t.string "check_key", null: false
    t.bigint "page_id"
    t.text "url"
    t.jsonb "details", default: {}, null: false
    t.float "priority_score"
    t.index ["crawl_id", "check_key", "priority_score"], name: "index_issues_on_crawl_id_and_check_key_and_priority_score"
    t.index ["crawl_id", "check_key"], name: "index_issues_on_crawl_id_and_check_key"
    t.index ["crawl_id", "page_id"], name: "index_issues_on_crawl_id_and_page_id"
  end

  create_table "links", force: :cascade do |t|
    t.bigint "crawl_id", null: false
    t.bigint "from_page_id", null: false
    t.text "to_url", null: false
    t.binary "to_url_hash", null: false
    t.boolean "internal", null: false
    t.text "anchor"
    t.string "rel", default: [], null: false, array: true
    t.bigint "to_page_id"
    t.index ["crawl_id", "to_url_hash"], name: "index_links_on_crawl_id_and_to_url_hash"
    t.index ["from_page_id"], name: "index_links_on_from_page_id"
  end

  create_table "page_bodies", primary_key: "page_id", force: :cascade do |t|
    t.binary "body_gzip", null: false
  end

  create_table "page_structured_data", force: :cascade do |t|
    t.bigint "page_id", null: false
    t.string "syntax", null: false
    t.string "types", default: [], null: false, array: true
    t.jsonb "data"
    t.boolean "valid_syntax", default: true, null: false
    t.jsonb "validation_errors", default: [], null: false
    t.jsonb "validation_warnings", default: [], null: false
    t.index ["page_id"], name: "index_page_structured_data_on_page_id"
  end

  create_table "pages", force: :cascade do |t|
    t.bigint "crawl_id", null: false
    t.bigint "crawl_url_id", null: false
    t.text "url", null: false
    t.integer "depth"
    t.boolean "in_sitemap", default: false, null: false
    t.integer "status_code"
    t.text "redirect_url"
    t.string "fetch_error"
    t.string "content_type"
    t.integer "content_length"
    t.boolean "truncated", default: false, null: false
    t.integer "response_ms"
    t.string "ip"
    t.jsonb "headers", default: {}, null: false
    t.datetime "fetched_at", null: false
    t.boolean "extracted", default: false, null: false
    t.text "title"
    t.integer "title_count"
    t.text "meta_description"
    t.integer "meta_description_count"
    t.string "meta_robots"
    t.string "x_robots_tag"
    t.boolean "noindex", default: false, null: false
    t.boolean "nofollow", default: false, null: false
    t.text "canonical_hrefs", default: [], null: false, array: true
    t.text "canonical"
    t.boolean "indexable", default: false, null: false
    t.string "indexability_reason"
    t.string "lang"
    t.string "charset"
    t.string "viewport"
    t.jsonb "hreflang", default: [], null: false
    t.text "h1", default: [], null: false, array: true
    t.jsonb "headings", default: [], null: false
    t.integer "word_count"
    t.bigint "text_simhash"
    t.binary "title_hash"
    t.binary "description_hash"
    t.integer "images_count"
    t.integer "images_missing_alt"
    t.integer "mixed_content_count"
    t.text "mixed_content_samples", default: [], null: false, array: true
    t.integer "links_count"
    t.jsonb "open_graph", default: {}, null: false
    t.integer "inlinks_count", default: 0, null: false
    t.integer "outlinks_internal", default: 0, null: false
    t.integer "outlinks_external", default: 0, null: false
    t.float "internal_pagerank"
    t.index ["crawl_id", "description_hash"], name: "index_pages_on_crawl_id_and_description_hash"
    t.index ["crawl_id", "id"], name: "index_pages_on_crawl_id_and_id"
    t.index ["crawl_id", "status_code"], name: "index_pages_on_crawl_id_and_status_code"
    t.index ["crawl_id", "title_hash"], name: "index_pages_on_crawl_id_and_title_hash"
    t.index ["crawl_url_id"], name: "index_pages_on_crawl_url_id", unique: true
  end

  create_table "performance_results", force: :cascade do |t|
    t.bigint "crawl_id", null: false
    t.bigint "page_id", null: false
    t.string "strategy", default: "mobile", null: false
    t.integer "performance_score"
    t.integer "lcp_ms"
    t.float "cls"
    t.integer "tbt_ms"
    t.integer "fcp_ms"
    t.integer "speed_index_ms"
    t.integer "ttfb_ms"
    t.jsonb "opportunities", default: [], null: false
    t.string "field_scope"
    t.string "field_category"
    t.integer "field_lcp_ms"
    t.float "field_cls"
    t.integer "field_inp_ms"
    t.string "error"
    t.datetime "fetched_at", null: false
    t.index ["crawl_id", "page_id", "strategy"], name: "index_performance_results_on_crawl_id_and_page_id_and_strategy", unique: true
    t.index ["page_id"], name: "index_performance_results_on_page_id"
  end

  create_table "projects", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.integer "monthly_api_budget_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "reports", force: :cascade do |t|
    t.bigint "crawl_id", null: false
    t.string "kind", null: false
    t.string "status", default: "pending", null: false
    t.string "filename"
    t.string "content_type"
    t.binary "data"
    t.integer "byte_size"
    t.string "error"
    t.datetime "generated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["crawl_id"], name: "index_reports_on_crawl_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.citext "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "crawl_hosts", "crawls", on_delete: :cascade
  add_foreign_key "crawl_urls", "crawls", on_delete: :cascade
  add_foreign_key "crawls", "domains", on_delete: :cascade
  add_foreign_key "crawls", "projects", on_delete: :cascade
  add_foreign_key "domains", "projects", on_delete: :cascade
  add_foreign_key "external_link_checks", "crawls", on_delete: :cascade
  add_foreign_key "issues", "crawls", on_delete: :cascade
  add_foreign_key "issues", "pages", on_delete: :cascade
  add_foreign_key "links", "crawls", on_delete: :cascade
  add_foreign_key "links", "pages", column: "from_page_id", on_delete: :cascade
  add_foreign_key "links", "pages", column: "to_page_id", on_delete: :nullify
  add_foreign_key "page_bodies", "pages", on_delete: :cascade
  add_foreign_key "page_structured_data", "pages", on_delete: :cascade
  add_foreign_key "pages", "crawl_urls", on_delete: :cascade
  add_foreign_key "pages", "crawls", on_delete: :cascade
  add_foreign_key "performance_results", "crawls", on_delete: :cascade
  add_foreign_key "performance_results", "pages", on_delete: :cascade
  add_foreign_key "projects", "users", on_delete: :cascade
  add_foreign_key "reports", "crawls", on_delete: :cascade
  add_foreign_key "sessions", "users", on_delete: :cascade
end
