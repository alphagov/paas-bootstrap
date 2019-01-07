require 'open3'

def merge_fixtures(fixtures)
  final = {}
  fixtures.each do |fixture|
    new_fixture = YAML.load_file(File.expand_path(fixture, __FILE__))
    final.merge!(new_fixture) { |_key, a_val, b_val| a_val.merge b_val }
  end
  final
end

RSpec.describe "manifest generation" do
  let(:fixtures) {
    merge_fixtures [
      "../../../shared/spec/fixtures/concourse-terraform-outputs.yml",
      "../../../shared/spec/fixtures/vpc-terraform-outputs.yml",
    ]
  }

  let(:concourse_instance_group) { manifest_with_defaults.fetch("instance_groups").find { |ig| ig["name"] == "concourse" } }
  let(:atc_job) { concourse_instance_group.fetch("jobs").find { |j| j["name"] == "atc" } }

  it "gets values from vpc terraform outputs" do
    expect(
      manifest_with_defaults["resource_pools"].first["cloud_properties"]["availability_zone"]
    ).to eq(fixtures["terraform_outputs_zone0"])
  end

  it "gets values from concourse terraform outputs" do
    expect(
      atc_job.fetch("properties").fetch("external_url")
    ).to eq("https://" + fixtures["terraform_outputs_concourse_dns_name"])
  end

  it "gets values from secrets" do
    expect(
      atc_job.fetch("properties").fetch("add_local_users")[0].split(':', 2)[1]
    ).to eq(concourse_secrets_value("concourse_atc_password"))
  end
end
