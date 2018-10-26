RSpec.describe "manifest properties validations" do
  let(:manifest) { manifest_with_defaults }
  let(:bosh_instance_group) { manifest.fetch("instance_groups").select { |x| x["name"] == "bosh" }.first }
  let(:bosh_properties) { bosh_instance_group.fetch("properties") }

  it "disables the health manager resurrector" do
    expect(bosh_properties["hm"]["resurrector_enabled"]).to eq(false)
  end

  it "sets the bosh director name to the value of DEPLOY_ENV" do
    expect(bosh_properties["director"]["name"]).to eq(ManifestHelpers.deploy_env)
  end
end
