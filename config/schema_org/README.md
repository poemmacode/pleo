# schema.org vocabulary

`vocabulary.json` is an extract (types with their hierarchy, properties with their domains, and
enumeration members) of the vocabulary published at https://schema.org, under the
[CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) licence. `Audit::SchemaValidator`
uses it to detect unknown types and properties.

Regenerate:

    bin/rails schema_org:refresh

`required_properties.yml` holds our own rules, written from Google Search Central's public
documentation on rich results. They are not a schema.org requirement.
