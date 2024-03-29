require "openssl"

RSpec.describe "rds bundle manifest validations" do
  let(:manifest) { manifest_with_defaults }

  describe "credhub" do
    it "is configured to require tls and ca certs are specificed" do
      data_storage = manifest["instance_groups"]
        .find { |g| g["name"] == "bosh" }["jobs"]
        .find { |j| j["name"] == "credhub" }
        .dig("properties", "credhub", "data_storage")

      expect(data_storage["require_tls"]).to eq(true)

      expect(data_storage["tls_ca"]).to match(/BEGIN CERTIFICATE/)
      expect(data_storage["tls_ca"]).to match(/END CERTIFICATE/)

      certs = OpenSSL::X509::Certificate.new data_storage["tls_ca"]

      expect(certs.issuer.to_s).to match(/Amazon/)
    end
  end

  describe "uaa" do
    it "is configured with the correct ca_certs" do
      ca_certs = manifest["instance_groups"]
        .find { |g| g["name"] == "bosh" }["jobs"]
        .find { |j| j["name"] == "uaa" }
        .dig("properties", "uaa", "ca_certs")

      expect(ca_certs.length).to be > 0

      expect(ca_certs).to include(
        match(/BEGIN CERTIFICATE/),
        match(/END CERTIFICATE/),
      )

      expect(ca_certs).to include(
        satisfy do |bundle|
          OpenSSL::X509::Certificate.new(bundle).issuer.to_s.match?(/Amazon/)
        end,
      )
    end
  end
end
