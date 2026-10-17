module ProjectSerializer
  def self.call(project)
    {
      id: project.id,
      name: project.name,
      monthly_api_budget_cents: project.monthly_api_budget_cents,
      domains: project.domains.sort_by(&:host).map { DomainSerializer.call(_1) },
      created_at: project.created_at
    }
  end
end
