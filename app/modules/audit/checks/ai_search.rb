module Audit
  module Checks
    module AiSearch
      class BotsBlocked < Check
        site_wide!
        define key: "ai.bots_blocked", category: "ai_search", severity: "warning", weight: 3

        def findings
          blocked = context.site_facts["ai_bots_blocked"].to_a
          blocked.any? ? [ site_finding({ bots: blocked }) ] : []
        end
      end

      class LlmsTxtMissing < Check
        site_wide!
        define key: "ai.llms_txt_missing", category: "ai_search", severity: "notice", weight: 1

        def findings
          facts = context.site_facts["llms_txt"]
          facts && facts["present"] == false ? [ site_finding({ status: facts["status"] }, url: facts["url"]) ] : []
        end
      end
    end
  end
end
