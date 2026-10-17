module Crawling
  # Validates and queues a new crawl (POST /projects/:id/crawls).
  class CreateCrawl
    MAX_ACTIVE_PER_USER = 2

    Result = Data.define(:crawl, :errors, :status)

    # params: a Hash with symbol keys (domain_id, terms_accepted and CrawlConfig attributes).
    def initialize(project, params)
      @project = project
      @params = params.to_h.symbolize_keys
    end

    def call
      domain = @project.domains.find(@params[:domain_id])
      config = CrawlConfig.build(@params.except(:domain_id, :terms_accepted), domain:, terms_accepted: @params[:terms_accepted])
      return failure(validation_errors(config)) unless config.valid?
      return failure([ error("crawl_in_progress", "Ya hay un crawl activo para #{domain.host}") ], :conflict) if host_busy?(domain)
      return failure([ error("too_many_crawls", "Máximo #{MAX_ACTIVE_PER_USER} crawls activos a la vez") ], :conflict) if user_busy?

      SafeHttp::Client.new.preflight!(config.start_url)

      crawl = @project.crawls.create!(
        domain:, config: config.to_stored, current_rps: config.requests_per_second,
        terms_accepted_at: domain.verified? ? nil : Time.current
      )
      StartCrawlJob.perform_later(crawl.id)
      Result.new(crawl, [], :accepted)
    rescue SafeHttp::Errors::UnsafeTarget => e
      failure([ error("unsafe_target", e.message, "start_url") ])
    rescue SafeHttp::Errors::Base => e
      failure([ error("start_url_unreachable", e.message, "start_url") ])
    end

    private
      # One active crawl per host across all users protects the target server.
      def host_busy?(domain)
        Crawl.active.or(Crawl.where(status: "paused")).joins(:domain).where(domains: { host: domain.host }).exists?
      end

      def user_busy?
        Crawl.active.joins(:project).where(projects: { user_id: @project.user_id }).count >= MAX_ACTIVE_PER_USER
      end

      def validation_errors(config)
        config.errors.map { |e| error("invalid", e.full_message, e.attribute.to_s) }
      end

      def error(code, detail, field = nil) = { code:, detail:, field: }.compact

      def failure(errors, status = :unprocessable_entity) = Result.new(nil, errors, status)
  end
end
