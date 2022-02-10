#!/usr/bin/env ruby
# rubocop:disable Layout/MultilineMethodCallIndentation
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/AbcSize
#
# frozen_string_literal: true

require 'openssl'
require 'yaml'

CERT_REGEX = /[-]{5}\s*BEGIN CERTIFICATE\s*[-]{5}[^-]*[-]{5}\s*END CERTIFICATE\s*[-]{5}/m.freeze
PRE_WARNING_DAYS = 400

ManifestCert = Struct.new(:filepath, :path, :cert, keyword_init: true)

def find_certificates(yaml, path)
  return [] if yaml.is_a? Numeric
  return [] if yaml.is_a? TrueClass
  return [] if yaml.is_a? FalseClass

  if yaml.is_a? String
    return yaml.scan(CERT_REGEX).map do |cert_str|
      ManifestCert.new(
        path: path,
        cert: OpenSSL::X509::Certificate.new(cert_str)
      )
    end
  end

  if yaml.is_a? Array
    return yaml.each_with_index.map do |v, k|
      find_certificates(v, "#{path}/#{k}")
    end
  end

  if yaml.is_a? Hash
    return yaml.map do |k, v|
      find_certificates(v, "#{path}/#{k}")
    end
  end

  raise "Unknown class #{yaml.class}"
end

manifest_certs = []

puts ARGV

ARGV.each do |filepath|
  puts "Finding certificates in #{filepath}"
  yaml = YAML.safe_load(File.read(filepath))

  initial_path = ''
  certs = find_certificates(yaml, initial_path).flatten
  certs.each { |cert| cert.filepath = filepath }

  puts "Found #{certs.length} certs"

  manifest_certs += certs
end

expd_manifest_certs = manifest_certs.select do |cert|
  cert.cert.not_after <= Time.now
end

n_days_time = Time.now + (PRE_WARNING_DAYS * 86_400)
exp_manifest_certs = manifest_certs
  .select { |cert| cert.cert.not_after <= n_days_time }
  .select { |cert| cert.cert.not_after >= Time.now }

puts
puts "Found #{manifest_certs.length} certs"

puts
puts "Found #{expd_manifest_certs.length} expired certs:"
expd_manifest_certs.group_by(&:filepath).each do |filepath, certs|
  puts "  filepath: #{filepath}"
  puts '  certs:'
  certs.each do |cert|
    puts "    - path:    #{cert.path}"
    puts "      expired: #{cert.cert.not_after}"
    puts "      subject: #{cert.cert.subject}"
    puts "      issuer:  #{cert.cert.issuer}"
  end
end

puts
puts "Found #{exp_manifest_certs.length} certs close to expiry:"
exp_manifest_certs.group_by(&:filepath).each do |filepath, certs|
  puts "  filepath: #{filepath}"
  puts '  certs:'
  certs.each do |cert|
    expiry_days = ((cert.cert.not_after - Time.now) / 86_400).to_i
    puts "    - path:       #{cert.path}:"
    puts "      expires:    #{cert.cert.not_after}"
    puts "      subject:    #{cert.cert.subject}"
    puts "      issuer:     #{cert.cert.issuer}"
    puts "      expires in: #{expiry_days} days"
  end
end

exit 1 unless expd_manifest_certs.empty?
exit 1 unless exp_manifest_certs.empty?
# rubocop:enable Layout/MultilineMethodCallIndentation
# rubocop:enable Metrics/MethodLength
# rubocop:enable Metrics/CyclomaticComplexity
# rubocop:enable Metrics/AbcSize
