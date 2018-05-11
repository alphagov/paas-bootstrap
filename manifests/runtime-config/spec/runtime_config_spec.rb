
RSpec.describe "Runtime config" do
  let(:runtime_config) { default_runtime_config }

  it "uses a shared collectd config file" do
    collectd_addon = runtime_config.fetch("addons").find { |addon| addon["name"] == "collectd" }
    expect(collectd_addon.fetch("properties").fetch("collectd").fetch("interval")).to eq 10
  end

  describe "datadog addon" do
    let(:datadog_addon) { runtime_config.fetch("addons").find { |addon| addon["name"] == "datadog-agent" } }

    it "has datadog included with properties from shared config" do
      expect(datadog_addon.fetch("properties").fetch("use_dogstatsd")).to eq false
    end

    it "adds aws_account as a tag to datadog" do
      expect(datadog_addon.fetch("properties").fetch("tags")).not_to be_nil
      expect(datadog_addon.fetch("properties").fetch("tags").fetch("aws_account")).to eq(ENV["AWS_ACCOUNT"])
    end

    it "adds deploy_env from the terraform environment as a tag to datadog" do
      expect(datadog_addon.fetch("properties").fetch("tags")).not_to be_nil
      terraform_environment = terraform_fixture("environment")
      expect(datadog_addon.fetch("properties").fetch("tags").fetch("deploy_env")).to eq(terraform_environment)
    end
  end

  describe "syslog_forwarder addon" do
    it "has the syslog_forwarder is configured as a addon" do
      syslog_forwarder_addon = runtime_config.fetch("addons").find { |addon| addon["name"] == "syslog_forwarder" }

      expect(syslog_forwarder_addon).not_to be_nil
      syslog_forwarder_job = syslog_forwarder_addon.fetch("jobs").find { |job| job["name"] == "syslog_forwarder" }
      expect(syslog_forwarder_job).not_to be_nil
    end

    it "has syslog_forwarder configured based on the variable $LOGIT_SYSLOG_ADDRESS" do
      syslog_forwarder_addon = runtime_config.fetch("addons").find { |addon| addon["name"] == "syslog_forwarder" }
      syslog_forwarder_address = syslog_forwarder_addon.fetch("properties").fetch("syslog").fetch("address")

      expect(syslog_forwarder_address).to eq ManifestHelpers::LOGIT_SYSLOG_ADDRESS
    end

    it "has syslog_forwarder configured based on the variable $LOGIT_SYSLOG_PORT" do
      syslog_forwarder_addon = runtime_config.fetch("addons").find { |addon| addon["name"] == "syslog_forwarder" }
      syslog_forwarder_port = syslog_forwarder_addon.fetch("properties").fetch("syslog").fetch("port")

      expect(syslog_forwarder_port).to eq ManifestHelpers::LOGIT_SYSLOG_PORT
    end

    it "has syslog_forwarder configured with a permitted_peer of *.logit.io" do
      syslog_forwarder_addon = runtime_config.fetch("addons").find { |addon| addon["name"] == "syslog_forwarder" }
      syslog_forwarder_permitted_peer = syslog_forwarder_addon.fetch("properties").fetch("syslog").fetch("permitted_peer")

      expect(syslog_forwarder_permitted_peer).to eq "*.logit.io"
    end

    # it "has syslog_forwarder configured with a address based on the variable $SYSTEM_DNS_ZONE_NAME" do
    #   syslog_forwarder_addon = runtime_config.fetch("addons").find { |addon| addon["name"] == "syslog_forwarder" }
    #   syslog_forwarder_address = syslog_forwarder_addon.fetch("properties").fetch("syslog").fetch("address")
    #
    #   expect(syslog_forwarder_address).to eq "logsearch-ingestor.#{ManifestHelpers::SYSTEM_DNS_ZONE_NAME}"
    # end
    #
    # it "has syslog_forwarder configured with a permitted_peer based on the variable $SYSTEM_DNS_ZONE_NAME" do
    #   syslog_forwarder_addon = runtime_config.fetch("addons").find { |addon| addon["name"] == "syslog_forwarder" }
    #   syslog_forwarder_permitted_peer = syslog_forwarder_addon.fetch("properties").fetch("syslog").fetch("permitted_peer")
    #
    #   expect(syslog_forwarder_permitted_peer).to eq "*.#{ManifestHelpers::SYSTEM_DNS_ZONE_NAME}"
    # end

    it "has syslog_forwarder configured with tls enabled" do
      syslog_forwarder_addon = runtime_config.fetch("addons").find { |addon| addon["name"] == "syslog_forwarder" }
      syslog_forwarder_tls_enabled = syslog_forwarder_addon.fetch("properties").fetch("syslog").fetch("tls_enabled")

      expect(syslog_forwarder_tls_enabled).to be true
    end

    it "has syslog_forwarder configured based on the variable $LOGIT_CA_CERT" do
      syslog_forwarder_addon = runtime_config.fetch("addons").find { |addon| addon["name"] == "syslog_forwarder" }
      syslog_forwarder_port = syslog_forwarder_addon.fetch("properties").fetch("syslog").fetch("ca_cert")

      expect(syslog_forwarder_port).to eq ManifestHelpers::LOGIT_CA_CERT
    end

    it "has syslog_forwarder configured with client tls enabled" do
      syslog_forwarder_addon = runtime_config.fetch("addons").find { |addon| addon["name"] == "syslog_forwarder" }
      syslog_forwarder_client_tls_enabled = syslog_forwarder_addon.fetch("properties").fetch("syslog").fetch("client_tls.enabled")

      expect(syslog_forwarder_client_tls_enabled).to be true
    end

    it "has syslog_forwarder configured based on the variable $LOGIT_CLIENT_CERT" do
      syslog_forwarder_addon = runtime_config.fetch("addons").find { |addon| addon["name"] == "syslog_forwarder" }
      syslog_forwarder_client_tls_cert = syslog_forwarder_addon.fetch("properties").fetch("syslog").fetch("client_tls.cert")

      expect(syslog_forwarder_client_tls_cert).to eq ManifestHelpers::LOGIT_CLIENT_CERT
    end

    it "has syslog_forwarder configured based on the variable $LOGIT_CLIENT_KEY" do
      syslog_forwarder_addon = runtime_config.fetch("addons").find { |addon| addon["name"] == "syslog_forwarder" }
      syslog_forwarder_client_tls_key = syslog_forwarder_addon.fetch("properties").fetch("syslog").fetch("client_tls.key")

      expect(syslog_forwarder_client_tls_key).to eq ManifestHelpers::LOGIT_CLIENT_KEY
    end
  end
end
