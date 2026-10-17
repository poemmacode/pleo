module Audit
  module Checks
    module AiSearch
      class BotsBlocked < Check
        define key: "ai.bots_blocked", category: "ai_search", severity: "warning", weight: 3,
          title: "robots.txt bloquea rastreadores de IA",
          description: "Algunos rastreadores de buscadores y asistentes de IA no pueden leer el sitio. Puede ser intencionado; revisa que lo sea.",
          fix: "Si quieres aparecer en respuestas de IA, permite esos user-agents en robots.txt."

        def findings
          blocked = context.site_facts["ai_bots_blocked"].to_a
          blocked.any? ? [ site_finding({ bots: blocked }) ] : []
        end
      end

      class LlmsTxtMissing < Check
        define key: "ai.llms_txt_missing", category: "ai_search", severity: "notice", weight: 1,
          title: "Sin llms.txt",
          description: "llms.txt es una propuesta para resumir el sitio a modelos de lenguaje; aún no es un estándar ni garantiza efectos.",
          fix: "Opcional: publica /llms.txt con un resumen y enlaces a tus páginas clave."

        def findings
          facts = context.site_facts["llms_txt"]
          facts && facts["present"] == false ? [ site_finding({ status: facts["status"] }, url: facts["url"]) ] : []
        end
      end
    end
  end
end
