# Vocabulario schema.org

`vocabulary.json` es un extracto (tipos con su jerarquía, propiedades con sus dominios y miembros de
enumeraciones) del vocabulario publicado en https://schema.org, bajo licencia
[CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/). Lo usa `Audit::SchemaValidator`
para detectar tipos y propiedades desconocidos.

Regenerar:

    bin/rails schema_org:refresh

`required_properties.yml` son reglas propias, redactadas a partir de la documentación pública de
Google Search Central sobre resultados enriquecidos. No son un requisito de schema.org.
