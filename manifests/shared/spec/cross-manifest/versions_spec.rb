require "cgi"
require "uri"
require "yaml"

RSpec.describe "versions" do
  describe "stemcell version" do
    it "uses the same version in Concourse and Bosh" do
      bosh_ops_file = YAML.load_file("../bosh-manifest/operations.d/030-set-stemcell.yml")
      concourse_manifest = YAML.load_file("../concourse-manifest/concourse-base.yml")

      bosh_version = CGI.parse(URI(bosh_ops_file[0]["value"]["url"]).query)["v"][0]
      concourse_version = concourse_manifest["meta"]["stemcell"]["version"]

      expect(bosh_version).to eq(concourse_version), "bosh and concourse should use the same version of the stemcell"
    end
  end
end
