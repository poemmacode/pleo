module Audit
  # Issue counts per check, joined with their catalog entries, most severe first (crawl page and reports).
  class Summary
    SEVERITY_ORDER = %w[error warning notice].freeze
    Entry = Data.define(:check_key, :category, :severity, :weight, :title, :description, :how_to_fix, :count)

    def initialize(crawl)
      @crawl = crawl
    end

    def entries
      @entries ||= begin
        counts = @crawl.issues.group(:check_key).count
        CheckDefinition.where(key: counts.keys).map do |definition|
          Entry.new(check_key: definition.key, category: definition.category, severity: definition.severity, weight: definition.weight,
                    title: definition.title, description: definition.description, how_to_fix: definition.how_to_fix,
                    count: counts[definition.key])
        end.sort_by { [ SEVERITY_ORDER.index(_1.severity), -_1.weight, -_1.count ] }
      end
    end

    def by_severity
      SEVERITY_ORDER.index_with { |severity| entries.select { _1.severity == severity }.sum(&:count) }
    end
  end
end
