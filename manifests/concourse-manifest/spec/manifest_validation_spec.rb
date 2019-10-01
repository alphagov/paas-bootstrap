
RSpec.describe "generic manifest validations" do
  let(:manifest) { manifest_with_defaults }

  describe "name uniqueness" do
    %w(
      instance_groups
      releases
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
    specify "all instance_group jobs reference releases that exist" do
      release_names = manifest["releases"].map { |r| r["name"] }

      manifest["instance_groups"].each do |ig|
        ig["jobs"].each do |job|
          expect(release_names).to include(job["release"]),
            "release #{job['release']} not found for job #{job['name']} in instance_group #{ig['name']}"
        end
      end
    end
  end
end
