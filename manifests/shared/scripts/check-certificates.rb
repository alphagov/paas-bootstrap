#!/usr/bin/env ruby

require "openssl"
require "yaml"
require "optparse"

CERT_REGEX = /-{5}\s*BEGIN CERTIFICATE\s*-{5}[^-]*-{5}\s*END CERTIFICATE\s*-{5}/m

options = {
  min_remaining_days: 180,
  skip_ca_certs: false,
}
option_parser = OptionParser.new do |opts|
  opts.on("--min-remaining-days [DAYS]", Integer) do |days|
    options[:min_remaining_days] = days
  end
  opts.on("--skip-ca-certs") do
    options[:skip_ca_certs] = true
  end
end
option_parser.parse!

ManifestCert = Struct.new(:filepath, :path, :cert, keyword_init: true)

def basic_constraints_value(cert)
  cert.extensions.find { |ext| ext.oid == "basicConstraints" }.value
end

def is_ca(cert)
  basic_constraints_value(cert) != "CA:FALSE"
end

def find_certificates(yaml, path, skip_ca_certs)
  return [] if yaml.is_a? Numeric
  return [] if yaml.is_a? TrueClass
  return [] if yaml.is_a? FalseClass

  if yaml.is_a? String
    return yaml.scan(CERT_REGEX).map do |cert_str|
      cert = OpenSSL::X509::Certificate.new(cert_str)

      return [] if skip_ca_certs && is_ca(cert)

      ManifestCert.new(
        path:,
        cert:,
      )
    end
  end

  if yaml.is_a? Array
    return yaml.each_with_index.map do |v, k|
      find_certificates(v, "#{path}/#{k}", skip_ca_certs)
    end
  end

  if yaml.is_a? Hash
    return yaml.map do |k, v|
      find_certificates(v, "#{path}/#{k}", skip_ca_certs)
    end
  end

  raise "Unknown class #{yaml.class}"
end

manifest_certs = []

raise "No filenames supplied" if ARGV.empty?

ARGV.each do |filepath|
  puts "Finding certificates in #{filepath}"
  yaml = YAML.safe_load(File.read(filepath))

  initial_path = ""
  certs = find_certificates(yaml, initial_path, options[:skip_ca_certs]).flatten
  certs.each { |cert| cert.filepath = filepath }

  puts "Found #{certs.length} certs"

  manifest_certs += certs
end

expired_manifest_certs = manifest_certs.select do |cert|
  cert.cert.not_after <= Time.now
end

n_days_time = Time.now + (options[:min_remaining_days] * 86_400)
expiring_manifest_certs = manifest_certs
  .select { |cert| cert.cert.not_after <= n_days_time }
  .select { |cert| cert.cert.not_after >= Time.now }

puts
puts "Found #{manifest_certs.length} certs"

puts
puts "Found #{expired_manifest_certs.length} expired certs:"
expired_manifest_certs.group_by(&:filepath).each do |filepath, certs|
  puts "  filepath: #{filepath}"
  puts "  certs:"
  certs.each do |cert|
    puts "    - path:             #{cert.path}"
    puts "      expired:          #{cert.cert.not_after}"
    puts "      subject:          #{cert.cert.subject}"
    puts "      issuer:           #{cert.cert.issuer}"
    puts "      basicConstraints: #{basic_constraints_value(cert.cert)}"
  end
end

puts
puts "Found #{expiring_manifest_certs.length} certs close to expiry:"
expiring_manifest_certs.group_by(&:filepath).each do |filepath, certs|
  puts "  filepath: #{filepath}"
  puts "  certs:"
  certs.each do |cert|
    expiry_days = ((cert.cert.not_after - Time.now) / 86_400).to_i
    puts "    - path:             #{cert.path}:"
    puts "      expires:          #{cert.cert.not_after}"
    puts "      subject:          #{cert.cert.subject}"
    puts "      issuer:           #{cert.cert.issuer}"
    puts "      basicConstraints: #{basic_constraints_value(cert.cert)}"
    puts "      expires in:       #{expiry_days} days"
  end
end

exit 1 unless expired_manifest_certs.empty?
exit 1 unless expiring_manifest_certs.empty?
