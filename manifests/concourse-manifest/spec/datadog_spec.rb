
RSpec.describe "datadog agent config" do
  let(:manifest) { manifest_with_defaults }

  let(:datadog_addon) { manifest.fetch("addons").find { |a| a["name"] == "datadog-agent" } }
  let(:datadog_job) { datadog_addon.fetch("jobs").find { |j| j["name"] == "datadog-agent" } }

  it "adds the datadog agent addon" do
    expect(datadog_addon).to be
  end

  it "adds aws_account as a tag to datadog" do
    expect(datadog_job["properties"]["tags"]["aws_account"]).to eq(ENV["AWS_ACCOUNT"])
  end

  it "adds deploy_env from the terraform environment as a tag to datadog" do
    expect(datadog_job["properties"]["tags"]["deploy_env"]).to eq("test")
  end
end
