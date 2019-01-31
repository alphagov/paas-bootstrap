module FixtureHelpers
  def terraform_fixture_value(key, fixture)
    YAML.load_file(fixtures_dir.join("#{fixture}-terraform-outputs.yml")).fetch("terraform_outputs_#{key}")
  end

  def copy_terraform_fixtures(target_dir, fixtures)
    fixtures.each do |fixture|
      copy_fixture_file("#{fixture}-terraform-outputs.yml", target_dir)
    end
  end

  def copy_fixture_file(file, target_dir, target_file = file)
    FileUtils.mkdir(target_dir) unless Dir.exist?(target_dir)
    FileUtils.cp(fixtures_dir.join(file), "#{target_dir}/#{target_file}")
  end

private

  def fixtures_dir
    Pathname.new(File.expand_path('../fixtures', __dir__))
  end
end

RSpec.configuration.include FixtureHelpers
