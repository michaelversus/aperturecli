# Version is managed by the VERSION file - do not edit manually
# Run the Release workflow to bump version automatically
class NSAssetsCLI < Formula
  APP_VERSION = File.read(File.join(__dir__, "VERSION")).strip.freeze

  desc "companion CLI for the NSAssets macOS application"
  homepage "https://github.com/michaelversus/aperturecli"
  url "https://github.com/michaelversus/aperturecli.git", tag: APP_VERSION
  version APP_VERSION

  depends_on "xcode": [:build]

  def install
    system "make", "install", "prefix=#{prefix}"
  end

  test do
    system "#{bin}/nsassetscli", "list"
  end
end
