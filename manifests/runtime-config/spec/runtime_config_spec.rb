
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

    it "has syslog_forwarder configured with tls enabled" do
      syslog_forwarder_addon = runtime_config.fetch("addons").find { |addon| addon["name"] == "syslog_forwarder" }
      syslog_forwarder_tls_enabled = syslog_forwarder_addon.fetch("properties").fetch("syslog").fetch("tls_enabled")

      expect(syslog_forwarder_tls_enabled).to be true
    end

    it "has syslog_forwarder configured based on the logit fixtures" do
      syslog_forwarder_addon = runtime_config.fetch("addons").find { |addon| addon["name"] == "syslog_forwarder" }
      syslog_forwarder_config = syslog_forwarder_addon.fetch("properties").fetch("syslog")

      expect(syslog_forwarder_config.fetch("address")).to eq "logit-syslog-url.internal"
      expect(syslog_forwarder_config.fetch("port")).to eq 6514
      expect(syslog_forwarder_config.fetch("permitted_peer")).to eq "*.logit.io"
      expect(syslog_forwarder_config.fetch("ca_cert")).to include("LOGIT_CA_CERT_1")
      expect(syslog_forwarder_config.fetch("ca_cert")).to include("LOGIT_CA_CERT_2")
    end
  end
end
