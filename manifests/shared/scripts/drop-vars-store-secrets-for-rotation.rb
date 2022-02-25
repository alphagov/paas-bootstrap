#!/usr/bin/env ruby

require "optparse"
require "yaml"

BLANK_CERT = {
  "ca" => "",
  "certificate" => "",
  "private_key" => "",
}.freeze

def parse_args
  options = { vars_to_preserve: [] }
  parser = OptionParser.new
  parser.banner = "Usage: drop-vars-store-secrets-for-rotation.rb [options]"
  parser.on("--ca", "Drop CA certs") { options[:ca] = true }
  parser.on("--leaf", "Drop leaf certs") { options[:leaf] = true }
  parser.on("--passwords", "Drop passwords") { options[:passwords] = true }
  parser.on("--rsa", "Drop rsa keys") { options[:rsa] = true }
  parser.on("--ssh", "Drop ssh keys") { options[:ssh] = true }
  parser.on("--delete-old", "Delete _old variables") { options[:delete] = true }
  parser.on("--manifest MANIFEST", "BOSH manifest") { |v| options[:manifest] = v }
  parser.on("--vars-store VARS", "BOSH variable store") { |v| options[:vars_store] = v }
  parser.on("--preserve VAR", "variables to not drop") do |v|
    options[:vars_to_preserve] << v
  end
  parser.parse!

  if options[:vars_store].nil? || options[:manifest].nil?
    raise "--manifest and --vars-store arguments are mandatory"
  end

  options
end

def rotate_secret(vars, vars_store, type, is_ca = false)
  vars_store = vars_store.clone
  var_names = vars.map { |v| v["name"] }
  vars.each do |var|
    name = var.fetch("name")
    next if name.end_with?("_old")
    next unless var["type"] == type
    next unless var.fetch("options", {}).fetch("is_ca", false) == is_ca
    next unless vars_store.is_a?(Hash) && vars_store.key?(name)

    if var_names.include? "#{name}_old"
      vars_store["#{name}_old"] = vars_store.delete(name)
    else
      vars_store.delete(name)
    end
  end

  vars_store
end

def delete_old(vars, vars_store)
  vars_store = vars_store.clone
  vars.each do |var|
    name = var.fetch("name")
    next unless name.end_with?("_old")

    if var["type"] == "certificate"
      vars_store[name] = BLANK_CERT
    else
      vars_store.delete(name)
    end
  end

  vars_store
end

# rubocop:disable Naming/MethodParameterName
def rotate(manifest, vars_store,
           ca: false,
           leaf: false,
           passwords: false,
           rsa: false,
           ssh: false,
           vars_to_preserve: [],
           delete: false)

  vars = manifest.fetch("variables").reject { |v| vars_to_preserve.include?(v["name"]) }

  if delete
    return delete_old(vars, vars_store)
  end

  vars_store = rotate_secret(vars, vars_store, "certificate", true) if ca
  vars_store = rotate_secret(vars, vars_store, "certificate", false) if leaf
  vars_store = rotate_secret(vars, vars_store, "password") if passwords
  vars_store = rotate_secret(vars, vars_store, "rsa") if rsa
  vars_store = rotate_secret(vars, vars_store, "ssh") if ssh

  vars_store
end
# rubocop:enable Naming/MethodParameterName

if $PROGRAM_NAME == __FILE__
  options = parse_args
  manifest = YAML.load_file(options.delete(:manifest))
  vars_store = YAML.load_file(options.delete(:vars_store))

  certs = rotate(manifest, vars_store, **options)
  puts certs.to_yaml
end
