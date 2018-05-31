
RSpec.describe "Runtime config" do
  let(:runtime_config) { default_runtime_config }

  describe "syslog_forwarder addon" do
    it "has the syslog_forwarder is configured as a addon" do
      syslog_forwarder_addon = runtime_config.fetch("addons").find { |addon| addon["name"] == "syslog_forwarder" }

      expect(syslog_forwarder_addon).not_to be_nil
      syslog_forwarder_job = syslog_forwarder_addon.fetch("jobs").find { |job| job["name"] == "syslog_forwarder" }
      expect(syslog_forwarder_job).not_to be_nil
    end

    it "has syslog_forwarder configured with a address based on the variable $SYSTEM_DNS_ZONE_NAME" do
      syslog_forwarder_addon = runtime_config.fetch("addons").find { |addon| addon["name"] == "syslog_forwarder" }
      syslog_forwarder_address = syslog_forwarder_addon.fetch("properties").fetch("syslog").fetch("address")

      expect(syslog_forwarder_address).to eq "logsearch-ingestor.#{ManifestHelpers::SYSTEM_DNS_ZONE_NAME}"
    end

    it "has syslog_forwarder configured with tls enabled" do
      syslog_forwarder_addon = runtime_config.fetch("addons").find { |addon| addon["name"] == "syslog_forwarder" }
      syslog_forwarder_tls_enabled = syslog_forwarder_addon.fetch("properties").fetch("syslog").fetch("tls_enabled")

      expect(syslog_forwarder_tls_enabled).to be true
    end

    it "has syslog_forwarder configured with a permitted_peer based on the variable $SYSTEM_DNS_ZONE_NAME" do
      syslog_forwarder_addon = runtime_config.fetch("addons").find { |addon| addon["name"] == "syslog_forwarder" }
      syslog_forwarder_permitted_peer = syslog_forwarder_addon.fetch("properties").fetch("syslog").fetch("permitted_peer")

      expect(syslog_forwarder_permitted_peer).to eq "*.#{ManifestHelpers::SYSTEM_DNS_ZONE_NAME}"
    end
  end
end
