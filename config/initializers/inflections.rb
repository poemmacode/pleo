# Basic Spanish plurals for pluralize/pluralize helpers under the :es locale
# (página → páginas, dominio → dominios, error → errores).
ActiveSupport::Inflector.inflections(:es) do |inflect|
  inflect.plural(/$/, "s")
  inflect.plural(/([^aeiouáéíóú])$/i, '\1es')
  inflect.plural(/([aeiouáéíóú])s$/i, '\1s')
  inflect.plural(/z$/i, "ces")
end
