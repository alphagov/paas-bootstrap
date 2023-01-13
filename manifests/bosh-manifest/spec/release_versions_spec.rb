require "uri"

RSpec.describe "release versions" do
  matcher :match_version_from_url do |url|
    match do |version|
      case url
      when %r{\?v=(.+)\z}
        url_version = Regexp.last_match(1)
      when %r{-([\d.]+)(-[0-9a-z\-.]+)?\.tgz\z}
        url_version = Regexp.last_match(1)
      else
        raise "Failed to extract version from URL '#{url}'"
      end

      version.to_s == url_version.to_s
    end
  end

  let(:manifest) { manifest_with_defaults }

  specify "release versions match their download URL version" do
    manifest.fetch("releases").each do |release|
      expect(release.fetch("version")).to match_version_from_url(release.fetch("url")),
        "expected release #{release['name']} version #{release['version']} to have matching version in URL: #{release['url']}"
    end
  end

  specify "manifest versions are not older than the ones in bosh-deployment" do
    def normalise_version(version)
      v = version
      Gem::Version.new(v.to_s.gsub(/^v/, "").gsub(/^([0-9]+)$/, '0.0.\1'))
    end

    # Versions to be pinned and corresponding upstream version
    #  "example" => {
    #    local: "1.1.1",
    #    upstream: "2.2.2"
    #  }
    pinned_releases = {}

    manifest_releases = manifest.fetch("releases").map { |release|
      [release["name"], release["version"]]
    }.to_h

    bosh_deployment_releases = bosh_deployment_manifest.fetch("releases").map { |release|
      [release["name"], release["version"]]
    }.to_h

    unpinned_bosh_deployment_releases = bosh_deployment_releases.reject { |name, _version|
      pinned_releases.key? name
    }.to_h

    unpinned_bosh_deployment_releases.each do |name, version|
      next unless manifest_releases.key? name

      expect(normalise_version(manifest_releases[name])).to be >= normalise_version(version),
        "expected #{name} release version #{manifest_releases[name]} to be older than #{version} as defined in bosh-deployment. Maybe you need to pin it?"
    end

    pinned_releases.each do |name, pinned_versions|
      expect(manifest_releases).to have_key(name), "expected pinned release #{name} for found in manifest"
      expect(bosh_deployment_releases).to have_key(name), "expected pinned release #{name} for found in bosh-deployment"
      expect(normalise_version(manifest_releases[name])).to be(normalise_version(pinned_versions[:local])),
         "expected #{name} to be using our own built tarball #{pinned_versions[:local]} not #{manifest_releases[name]}"

      expect(normalise_version(bosh_deployment_releases[name])).to be(normalise_version(pinned_versions[:upstream])),
        "expected #{name} upstream to be #{pinned_versions[:upstream]} not #{bosh_deployment_releases[name]}. We might need to rebase our forked #{name} release and generate a new tarball, or use the upstream version."
    end
  end
end
