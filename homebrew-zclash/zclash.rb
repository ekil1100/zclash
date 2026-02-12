class Zclash < Formula
  desc "High-performance proxy tool in Zig, compatible with Clash config"
  homepage "https://github.com/ekil1100/zclash"
  url "https://github.com/ekil1100/zclash/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"

  depends_on "zig" => :build

  def install
    system "zig", "build"
    bin.install "zig-out/bin/zclash"
  end

  test do
    system "#{bin}/zclash", "--help"
  end
end
