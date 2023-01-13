require 'yaml'

RSpec.describe 'pipeline validations' do
  ALL_PIPELINE_VARS = File
    .read(File.join(__dir__, '../scripts/pipelines.sh'))[/EOF.*EOF/m]
    .lines
    .reject { |l| l.match(/EOF|---/) }
    .map { |l| l.gsub(/:.*/, '').chomp }
    .concat(
      Dir
        .glob(File.join(__dir__, '../vars-files/*.yml'))
        .map { |f| YAML.safe_load(File.read(f), aliases: true).keys }
        .flatten
        .uniq
    )
    .concat(%w[vagrant_ssh_key_name test-secret concourse_web_password bosh-credhub-ca-cert bosh-credhub-admin])

  it 'should have pipeline variables' do
    expect(ALL_PIPELINE_VARS.length).to_not eq(0)
  end

  Dir
    .glob(File.join(__dir__, '../pipelines/*.yml'))
    .map { |filename| [filename, File.read(filename)] }
    .each do |filename, contents|
      describe "pipeline #{filename}" do

        it 'should be valid yaml' do
          expect { YAML.safe_load(contents, aliases: true) }.not_to raise_error
        end

        it 'should not contain any free variables' do
          pipeline_variables = contents
            .scan(/\(\(.*\)\)/)
            .map { |m| m.gsub(/[()]/, '') }
            .uniq

          free_variables = pipeline_variables - ALL_PIPELINE_VARS
          expect(free_variables.length).to eq(0), "Found #{free_variables.length} free variables: #{free_variables.inspect}"
        end

      end
    end
end
