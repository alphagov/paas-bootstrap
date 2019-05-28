#!/usr/bin/env ruby

require 'optparse'
require 'yaml'
require File.expand_path("../../../shared/lib/secret_generator", __FILE__)

generator = SecretGenerator.new(
  "concourse_web_password" => :simple,
  "concourse_token_signing_key" => :bosh_rsa_key,
  "concourse_tsa_host_key" => :bosh_ssh_key,
  "concourse_worker_key" => :bosh_ssh_key,
)

option_parser = OptionParser.new do |opts|
  opts.on('--existing-secrets FILE') do |file|
    existing_secrets = YAML.load_file(file)
    # An empty file parses as false
    generator.existing_secrets = existing_secrets["secrets"] if existing_secrets
  end
end
option_parser.parse!

output = { "secrets" => generator.generate }
puts output.to_yaml
