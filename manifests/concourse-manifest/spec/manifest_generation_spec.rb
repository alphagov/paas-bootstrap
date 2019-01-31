require 'open3'

RSpec.describe "manifest generation" do
  let(:manifest) { manifest_with_defaults }
  let(:concourse_instance_group) { manifest.fetch("instance_groups").find { |ig| ig["name"] == "concourse" } }
  let(:atc_job) { concourse_instance_group.fetch("jobs").find { |j| j["name"] == "atc" } }

  it "gets values from vpc terraform outputs" do
    expect(
      manifest_with_defaults["resource_pools"].first["cloud_properties"]["availability_zone"]
    ).to eq(terraform_fixture_value("zone0", "vpc"))
  end

  it "gets values from concourse terraform outputs" do
    expect(
      atc_job.fetch("properties").fetch("external_url")
    ).to eq("https://" + terraform_fixture_value("concourse_dns_name", "concourse"))
  end

  it "gets values from secrets" do
    expect(
      atc_job.fetch("properties").fetch("add_local_users")[0].split(':', 2)[1]
    ).to eq(concourse_secrets_value("concourse_atc_password"))
  end

  context "with github auth enabled" do
    let(:manifest) { manifest_with_github_auth }

    it "sets up the client_id and secret" do
      expect(
        atc_job.dig("properties", "github_auth", "client_id")
      ).not_to be_empty
      expect(
        atc_job.dig("properties", "github_auth", "client_secret")
      ).not_to be_empty
    end

    it "sets up the main team users" do
      expect(
        atc_job.dig("properties", "main_team", "auth", "github", "users")
      ).not_to be_empty
    end
  end
end
