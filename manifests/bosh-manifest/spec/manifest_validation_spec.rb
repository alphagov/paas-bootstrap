RSpec.describe "generic manifest validations" do
  let(:manifest) { manifest_with_defaults }

  describe "name uniqueness" do
    %w(
      disk_pools
      instance_groups
      networks
      releases
      resource_pools
    ).each do |resource_type|
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

  describe "cross-references runtime-config" do
    specify "runtime-config keys match manifest keys" do
      runtime_config = YAML.load_file(File.expand_path("../../runtime-config/runtime-config.yml", __dir__))
      user_add_config = nil

      # Find user add config
      manifest["instance_groups"].each do |ig|
        ig["jobs"].each do |job|
          if job["name"] == 'user_add'
            user_add_config = job
            break
          end
        end
      end

      expect(user_add_config).to_not be_nil, "user_add config is missing from the manifest"

      manifest_keys = user_add_config["properties"]["users"].map { |r| [r["name"], r["public_key"]] }.to_h
      runtime_keys = runtime_config["addons"][0]['jobs'][0]["properties"]["users"].map { |r|
        [r["name"], r["public_key"]]
      }.to_h

      # Compare manifest entries to runtime config
      manifest_keys.each do |name, pk|
        expect(runtime_keys.has_key?(name)).to be_truthy, "did not find username #{name} in the runtime config"
        expect(pk).to_not be_nil, "key for username #{name} is missing"
        expect(pk).to eq(runtime_keys[name]), "key for username #{name} is different in the runtime config and the manifest config"
      end

      # Compare runtime config to manifest entries
      runtime_keys.each do |name, pk|
        expect(manifest_keys.has_key?(name)).to be_truthy, "did not find username #{name} in the manifest config"
        expect(pk).to_not be_nil, "key for username #{name} is missing"
        expect(pk).to eq(manifest_keys[name]), "key for username #{name} is different in the manifest config and the runtime config"
      end
    end
  end

  describe "uaa" do
    let(:uaa_props) { bosh_jobs.find { |j| j['name'] == 'uaa' }['properties'] }

    context "login providers" do
      let(:uaa_google_login_provider) { uaa_props.dig('login', 'oauth', 'providers', 'google') }

      it 'should be configured to use google' do
        expect(uaa_google_login_provider).to_not be_nil
        expect(uaa_google_login_provider['issuer']).to eql 'https://accounts.google.com'
        expect(uaa_google_login_provider['type']).to eql 'oidc1.0'
        expect(uaa_google_login_provider['scopes']).to eql %w(openid profile email)
        expect(uaa_google_login_provider['relyingPartyId']).to eql 'some-google-client-id'
        expect(uaa_google_login_provider['relyingPartySecret']).to eql 'some-google-client-secret'
      end
    end
  end
end
