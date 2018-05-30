RSpec.describe "Gets properties from shared config" do
  let(:manifest) { manifest_with_defaults }
  let(:bosh_properties) { manifest.fetch("instance_groups").select { |x| x["name"] == "bosh" }.first["properties"] }

  it "for datadog" do
    expect(bosh_properties["use_dogstatsd"]).to eq false
  end
end
