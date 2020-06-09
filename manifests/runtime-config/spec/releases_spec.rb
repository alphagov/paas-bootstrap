RSpec.describe "runtime config releases" do
  let(:runtime_config) { runtime_config_with_defaults }
  let(:releases) { runtime_config.fetch("releases") }

  it "has releases" do
    expect(releases).to be_a Array
    expect(releases).not_to eq([])
  end

  %w[node-exporter awslogs].each do |release_name|
    it "has the #{release_name} release" do
      release = releases.find { |r| r["name"] == release_name }

      expect(release).not_to be_nil
    end
  end
end
