#!/usr/bin/env ruby

require "optparse"
require "yaml"
require File.expand_path("../../shared/lib/secret_generator", __dir__)

generator = SecretGenerator.new(
  "bosh_postgres_password" => :simple,
  "vcap_password" => :sha512_crypted,
  "bosh_credhub_admin_client_password" => :simple,
)

option_parser = OptionParser.new do |opts|
  opts.on("--existing-secrets FILE") do |file|
    existing_secrets = YAML.safe_load_file(file, aliases: true)
    # An empty file parses as false
    generator.existing_secrets = existing_secrets["secrets"] if existing_secrets
  end
end
option_parser.parse!

output = { "secrets" => generator.generate }
puts output.to_yaml
