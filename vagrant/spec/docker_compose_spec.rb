# Disable this cop because we are testing YAML anchors
# rubocop:disable Security/YAMLLoad

require "yaml"

RSpec.describe "docker-compose" do
  let(:docker_compose_yaml) do
    vagrant_dir = File.expand_path(File.join(__dir__, ".."))
    YAML.load(File.read("#{vagrant_dir}/docker-compose.yml"))
  end

  let(:services) { docker_compose_yaml["services"] }

  describe "images" do
    let(:service_images) { services.map { |_, i| i["image"] } }

    let(:service_image_versions) do
      service_images
      .map { |image_and_version| image_and_version.split(":") }
      .reduce({}) do |acc, i_and_v|
        i, v = i_and_v
        acc[i] ||= []
        acc[i] << v
        acc
      end
    end

    it "has the same version for each image" do
      service_image_versions.each do |image_name, versions|
        u = versions.uniq
        c = u.length
        expect(c).to eq(1), "#{image_name} has #{c} versions: #{u}"
      end
    end
  end
end
# rubocop:enable Security/YAMLLoad
