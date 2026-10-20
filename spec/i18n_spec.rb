require "rails_helper"

RSpec.describe "Spanish locale" do
  it "formats dates and times with every format the views use" do
    time = Time.utc(2026, 10, 20, 9, 5)

    expect(I18n.l(time, format: :short)).to eq("20 oct 09:05")
    expect(I18n.l(time.to_date, format: :long)).to eq("20 de octubre de 2026")
    expect(I18n.l(time)).to eq("20/10/2026 09:05")
  end

  it "pluralizes Spanish words used in the views" do
    helper = ApplicationController.helpers
    expect(helper.pluralize(1, "página")).to eq("1 página")
    expect(helper.pluralize(12, "página")).to eq("12 páginas")
    expect(helper.pluralize(2, "dominio")).to eq("2 dominios")
    expect("error".pluralize(:es)).to eq("errores")
  end
end
