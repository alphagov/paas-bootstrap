require "open3"

RSpec.describe "manifest generation" do
  let(:manifest) { manifest_with_defaults }
  let(:concourse_instance_group) { manifest.fetch("instance_groups").find { |ig| ig["name"] == "concourse" } }
  let(:web_job) { concourse_instance_group.fetch("jobs").find { |j| j["name"] == "web" } }

  it "gets the dns values from concourse terraform outputs" do
    expect(
      web_job.fetch("properties").fetch("external_url"),
    ).to eq("https://" + terraform_fixture_value("concourse_dns_name", "concourse"))
  end

  it "gets values from secrets" do
    expect(
      web_job.fetch("properties").fetch("add_local_users")[0].split(":", 2)[1],
    ).to eq("((concourse_web_password))")
  end

  it "gets the postgres values from concourse terraform outputs" do
    expect(
      web_job.dig("properties").fetch("postgresql"),
    ).to eq(
      "database" => terraform_fixture_value("concourse_db_name", "concourse"),
      "host" => terraform_fixture_value("concourse_db_address", "concourse"),
      "port" => terraform_fixture_value("concourse_db_port", "concourse"),
      "role" => {
        "name" => terraform_fixture_value("concourse_db_username", "concourse"),
        "password" => terraform_fixture_value("concourse_db_password", "concourse")
      },
    )
  end

  context "with github auth enabled" do
    let(:manifest) { manifest_with_github_auth }

    it "sets up the client_id and secret" do
      expect(
        web_job.dig("properties", "github_auth", "client_id"),
      ).not_to be_empty
      expect(
        web_job.dig("properties", "github_auth", "client_secret"),
      ).not_to be_empty
    end

    it "sets up the main team users" do
      expect(
        web_job.dig("properties", "main_team", "auth", "github", "users"),
      ).not_to be_empty
    end
  end
end
