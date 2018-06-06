RSpec.describe "datadog addon config" do
  let(:manifest) { manifest_with_defaults }

  let(:bosh_instance_group) { manifest.fetch("instance_groups").find { |x| x["name"] == "bosh" } }
  let(:bosh_properties) { bosh_instance_group.fetch('properties') }

  let(:datadog_job) { bosh_instance_group.fetch('jobs').find { |j| j['name'] == 'datadog-agent' } }
  let(:datadog_properties) { datadog_job.fetch('properties') }

  it "configures the datadog-agent job" do
    expect(datadog_job).to be
    expect(datadog_properties["enabled"]).to eq(true)
  end

  it "configures the datadog tags" do
    expect(datadog_properties["tags"]["bosh-job"]).to eq("bosh")
    expect(datadog_properties["tags"]["deploy_env"]).to eq("test")
  end

  it "adds hm datadog properties" do
    expect(bosh_properties["hm"]["datadog_enabled"]).to eq true
  end
end
