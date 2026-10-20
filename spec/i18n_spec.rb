require "rails_helper"

RSpec.describe "Internationalization" do
  def flatten(hash, prefix = nil)
    hash.flat_map { |key, value| value.is_a?(Hash) ? flatten(value, [ prefix, key ].compact.join(".")) : [ [ prefix, key ].compact.join(".") ] }
  end

  def keys(file, locale) = flatten(YAML.load_file(Rails.root.join("config/locales", file)).fetch(locale.to_s)).to_set

  it "uses English by default and offers Spanish" do
    expect(I18n.default_locale).to eq(:en)
    expect(I18n.available_locales).to eq(%i[en es])
  end

  it "has the same keys in English and Spanish" do
    shared_formats = /\A(date|time|number|errors)\./ # Rails ships English formats; Spanish defines its own
    expect(keys("es.yml", :es).reject { _1.match?(shared_formats) }).to match_array(keys("en.yml", :en))
    expect(keys("checks.es.yml", :es)).to eq(keys("checks.en.yml", :en))
  end

  it "has a title, description and fix for every check in both languages" do
    Audit::Catalog::CHECKS.each do |check|
      %w[title description fix].each do |field|
        %i[en es].each { |locale| expect(I18n.exists?("checks.#{check.key}.#{field}", locale)).to be(true), "#{locale} #{check.key}.#{field}" }
      end
    end
  end

  it "formats dates and pluralizes in each language" do
    time = Time.utc(2026, 10, 20, 9, 5)

    expect(I18n.l(time, format: :short)).to eq("20 Oct 09:05")
    I18n.with_locale(:es) do
      expect(I18n.l(time, format: :short)).to eq("20 oct 09:05")
      expect(I18n.l(time.to_date, format: :long)).to eq("20 de octubre de 2026")
      expect(I18n.t("crawls.duplicates.index.pages", count: 1)).to eq("1 página")
      expect(I18n.t("crawls.duplicates.index.pages", count: 12)).to eq("12 páginas")
    end
    expect(I18n.t("crawls.duplicates.index.pages", count: 12)).to eq("12 pages")
  end
end
