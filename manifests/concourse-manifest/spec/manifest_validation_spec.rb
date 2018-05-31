
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

  describe "addons cross-references" do
    specify "all addons reference releases that exist" do
      release_names = manifest["releases"].map { |r| r["name"] }

      manifest.fetch("addons", []).each do |addon|
        addon["jobs"].each do |job|
          expect(release_names).to include(job["release"]),
            "release #{job['release']} not found for job #{job['name']} in addon #{addon['name']}"
        end
      end
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
end
