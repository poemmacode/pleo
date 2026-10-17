class CrawlHost < ApplicationRecord
  belongs_to :crawl

  def robots_policy
    @robots_policy ||= case robots_outcome
    when "parsed" then SafeHttp::Robots::Parser.parse(robots_txt).policy_for
    when "unavailable" then SafeHttp::Robots::Policy.allow_all
    else SafeHttp::Robots::Policy.disallow_all
    end
  end
end
