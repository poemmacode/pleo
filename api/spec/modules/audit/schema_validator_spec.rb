require "rails_helper"

RSpec.describe Audit::SchemaValidator do
  def validate(data) = described_class.validate(data)

  it "accepts a complete Product with a nested Offer" do
    errors, warnings = validate(
      "@type" => "Product", "name" => "Zapatilla", "image" => "x.jpg", "description" => "d", "sku" => "1", "brand" => "B",
      "offers" => { "@type" => "Offer", "price" => "59.90", "priceCurrency" => "EUR", "availability" => "https://schema.org/InStock", "url" => "u" }
    )

    expect(errors).to be_empty
    expect(warnings).to be_empty
  end

  it "reports missing required and one-of properties with their path" do
    errors, = validate("@type" => "Product", "offers" => { "@type" => "Offer" })

    expect(errors).to contain_exactly(
      { code: "missing_required", type: "Product", property: "name" },
      { code: "missing_one_of", type: "Offer", property: "price | priceSpecification", path: "offers" }
    )
  end

  it "applies parent-type rules to subtypes" do
    errors, = validate("@type" => "Restaurant", "name" => "Casa Pepe")

    expect(errors).to include(code: "missing_required", type: "Restaurant", property: "address")
  end

  it "flags unknown types and properties" do
    errors, warnings = validate("@type" => "Prodcut", "name" => "x")
    expect(errors).to eq([ { code: "unknown_type", type: "Prodcut" } ])

    _, warnings = validate("@type" => "Organization", "name" => "A", "url" => "u", "logo" => "l", "fundador" => "x")
    expect(warnings).to eq([ { code: "unknown_property", type: "Organization", property: "fundador" } ])
  end

  it "validates every element of arrays (FAQ questions)" do
    errors, = validate(
      "@type" => "FAQPage",
      "mainEntity" => [
        { "@type" => "Question", "name" => "¿Q1?", "acceptedAnswer" => { "@type" => "Answer", "text" => "A1" } },
        { "@type" => "Question", "name" => "¿Q2?", "acceptedAnswer" => { "@type" => "Answer", "text" => " " } }
      ]
    )

    expect(errors).to eq([ { code: "missing_required", type: "Answer", property: "text", path: "mainEntity[1].acceptedAnswer" } ])
  end

  it "covers at least 8 types with required properties" do
    with_required = Audit::SchemaVocabulary.rules.count { |_, rule| rule["required"].present? || rule["one_of"].present? }
    expect(with_required).to be >= 8
  end

  it "knows the vocabulary hierarchy" do
    expect(Audit::SchemaVocabulary.ancestors("NewsArticle")).to include("Article", "CreativeWork", "Thing")
  end
end
