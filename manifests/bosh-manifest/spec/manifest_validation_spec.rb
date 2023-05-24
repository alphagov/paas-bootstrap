RSpec.describe "generic manifest validations" do
  let(:manifest) { manifest_with_defaults }
  let(:instance_groups) { manifest["instance_groups"] }
  let(:bosh_instance) { instance_groups.find { |ig| ig["name"] == "bosh" } }
  let(:bosh_jobs) { bosh_instance["jobs"] }
  let(:director) { bosh_instance.dig("properties", "director") }

  describe "instance" do
    it "has a big disk" do
      disk = bosh_instance["persistent_disk_pool"]

      disk_pools = manifest["disk_pools"]
      disk_pool = disk_pools.find { |p| p["name"] == disk }

      disk_size = disk_pool["disk_size"]
      expect(disk_size).to be >= 2.pow(17), "#{disk_pool} should be bigger"
    end
  end

  describe "name uniqueness" do
    %w[
      disk_pools
      instance_groups
      networks
      releases
      resource_pools
    ].each do |resource_type|
      specify "all #{resource_type} have a unique name" do
        all_resource_names = manifest.fetch(resource_type, []).map { |r| r["name"] }

        duplicated_names = all_resource_names.select { |n| all_resource_names.count(n) > 1 }.uniq
        expect(duplicated_names).to be_empty,
          "found duplicate names (#{duplicated_names.join(',')}) for #{resource_type}"
      end
    end
  end

  describe "IP address uniqueness" do
    specify "all instance_groups should use a unique IP address" do
      all_ips = manifest["instance_groups"].map { |ig|
        ig["networks"].map { |net| net["static_ips"] }
      }.flatten.compact

      duplicated_ips = all_ips.select { |ip| all_ips.count(ip) > 1 }.uniq
      expect(duplicated_ips).to be_empty,
        "found duplicate IP (#{duplicated_ips.join(',')})"
    end
  end

  describe "instance_group cross-references" do
    specify "all instance_groups reference resource_pools that exist" do
      resource_pool_names = manifest["resource_pools"].map { |r| r["name"] }

      manifest["instance_groups"].each do |ig|
        expect(resource_pool_names).to include(ig["resource_pool"]),
          "resource_pool #{ig['resource_pool']} not found for instance_group #{ig['name']}"
      end
    end

    specify "all instance_group jobs reference releases that exist" do
      release_names = manifest["releases"].map { |r| r["name"] }

      manifest["instance_groups"].each do |ig|
        ig["jobs"].each do |job|
          expect(release_names).to include(job["release"]),
            "release #{job['release']} not found for job #{job['name']} in instance_group #{ig['name']}"
        end
      end
    end

    specify "all instance_groups reference networks that exist" do
      network_names = manifest["networks"].map { |n| n["name"] }

      manifest["instance_groups"].each do |ig|
        ig["networks"].each do |network|
          expect(network_names).to include(network["name"]),
            "network #{network['name']} not found for instance_group #{ig['name']}"
        end
      end
    end

    specify "all instance_groups reference disk_pools that exist" do
      disk_pool_names = manifest.fetch("disk_pools", {}).map { |p| p["name"] }

      manifest["instance_groups"].each do |ig|
        next unless ig["persistent_disk_pool"]

        expect(disk_pool_names).to include(ig["persistent_disk_pool"]),
          "disk_pool #{ig['persistent_disk_pool']} not found for instance_group #{ig['name']}"
      end
    end
  end

  describe "resource_pools cross-references" do
    specify "all resource_pools reference networks that exist" do
      network_names = manifest["networks"].map { |n| n["name"] }

      manifest["resource_pools"].each do |pool|
        expect(network_names).to include(pool["network"]),
          "network #{pool['network']} not found for resource_pool #{pool['name']}"
      end
    end
  end

  describe "uaa" do
    let(:uaa_props) { bosh_jobs.find { |j| j["name"] == "uaa" }["properties"] }

    describe "login providers" do
      let(:uaa_google_login_provider) { uaa_props.dig("login", "oauth", "providers", "admin-google") }

      it "is configured to use google" do
        expect(uaa_google_login_provider).not_to be_nil
        expect(uaa_google_login_provider["issuer"]).to eql "https://accounts.google.com"
        expect(uaa_google_login_provider["type"]).to eql "oidc1.0"
        expect(uaa_google_login_provider["scopes"]).to eql %w[openid profile email]
        expect(uaa_google_login_provider["relyingPartyId"]).to eql "some-google-client-id"
        expect(uaa_google_login_provider["relyingPartySecret"]).to eql "some-google-client-secret"
      end
    end

    describe "clients" do
      let(:uaa_clients) { uaa_props.dig("uaa", "clients") }

      it "sets up a client for the credhub cli" do
        client = uaa_clients["credhub_cli"]

        expect(client["authorities"]).to eq("")
        expect(client["secret"]).to eq("")

        expect(client["scope"]).to eq("credhub.read,credhub.write")
      end

      it "sets up a client for the bosh cli" do
        client = uaa_clients["bosh_cli"]

        expect(client["authorities"]).to eq("uaa.none")
        expect(client["secret"]).to eq("")

        expect(client["scope"].split(",")).to include("openid", "bosh.admin")
      end
    end
  end

  describe "resource_pools" do
    let(:resource_pools) { manifest["resource_pools"] }
    let(:resource_pool) { resource_pools.first }

    describe "instance type" do
      let(:instance_type) { resource_pool.dig("cloud_properties", "instance_type") }

      it "is t3.medium" do
        expect(instance_type).to eq("t3.medium")
      end

      context "when not in development" do
        let(:manifest) { manifest_for_account("prod") }

        it "is c6i.xlarge" do
          expect(instance_type).to eq("c6i.xlarge")
        end
      end
    end
  end

  describe "director" do
    describe "tasks" do
      it "cleans up tasks every day" do
        schedule = director["tasks_cleanup_schedule"]
        expect(schedule).to eq("0 0 0 * * * UTC")
      end
    end
  end
end
