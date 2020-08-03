RSpec.describe "variables validations" do
  let(:manifest) { manifest_with_defaults }
  let(:vars) { manifest["variables"] }
  let(:certs) { vars.select { |v| v["type"] == "certificate" } }

  it "generates no certificates" do
    expect(certs).to be_empty
  end
end
