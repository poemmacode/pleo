module IssueSerializer
  def self.summary(definition, count)
    definition.slice(:category, :severity, :weight, :title, :description, :how_to_fix).symbolize_keys
      .merge(check_key: definition.key, count:)
  end
end
