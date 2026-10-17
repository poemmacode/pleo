module Audit
  module Checks
    module Https
      class NotUsed < PageCheck
        define key: "https.not_used", category: "https", severity: "error", weight: 8,
          title: "Páginas servidas por HTTP",
          description: "La página responde 200 por HTTP sin cifrar en lugar de redirigir a HTTPS.",
          fix: "Sirve todo el sitio por HTTPS y redirige con 301 cada URL http:// a su versión https://."

        def evaluate(page) = page.url.start_with?("http://")
      end

      class MixedContent < PageCheck
        define key: "https.mixed_content", category: "https", severity: "warning", weight: 5,
          title: "Contenido mixto",
          description: "Una página HTTPS carga recursos por HTTP; el navegador puede bloquearlos o marcar la página como insegura.",
          fix: "Carga esos recursos por HTTPS (o con URLs relativas al protocolo del sitio)."

        def evaluate(page) = page.mixed_content_count.to_i.positive? && { count: page.mixed_content_count, samples: page.mixed_content_samples }
      end

      class HttpLinks < Links::LinkQueryCheck
        define key: "https.http_links", category: "https", severity: "notice", weight: 2,
          title: "Enlaces internos a http://",
          description: "Páginas HTTPS enlazan a la versión HTTP de tu sitio, lo que provoca redirecciones evitables.",
          fix: "Actualiza los enlaces a https://."

        def query = grouped("links.internal AND links.to_url LIKE 'http://%' AND pages.url LIKE 'https://%'")
      end

      class CertInvalid < PageCheck
        define key: "https.cert_invalid", category: "https", severity: "error", weight: 9,
          title: "Certificado TLS inválido",
          description: "No se pudo establecer una conexión segura (certificado caducado, de otro host o sin cadena válida).",
          fix: "Renueva o corrige el certificado e incluye la cadena intermedia completa."

        def applies?(page) = page.fetch_error.present?
        def evaluate(page) = page.fetch_error.start_with?("Tls") && { error: page.fetch_error }
      end
    end
  end
end
