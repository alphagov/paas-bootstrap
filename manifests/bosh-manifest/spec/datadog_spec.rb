RSpec.describe "datadog addon config" do
  let(:manifest) { manifest_with_defaults }
  let(:addon) { manifest.fetch("addons").find { |a| a['name'] == 'datadog-agent' } }
  let(:addon_properties) { addon.fetch('jobs').find { |j| j['name'] == 'datadog-agent' }.fetch('properties') }


  let(:bosh_instance_group) { manifest.fetch("instance_groups").find { |x| x["name"] == "bosh" } }
  let(:bosh_properties) { bosh_instance_group.fetch('properties') }

  it "configures the datadog-agent addon" do
    expect(addon).to be
  end

  it "configures datadog tag bosh-job" do
    expect(addon_properties["tags"]["bosh-job"]).to eq("bosh")
  end

  it "adds hm datadog properties" do
    expect(bosh_properties["hm"]["datadog_enabled"]).to eq true
  end
end
