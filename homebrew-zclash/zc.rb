class Zc < Formula
  desc "Lightweight network tool built with Zig"
  homepage "https://github.com/ekil1100/zc"
  url "https://github.com/ekil1100/zc/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"

  depends_on "zig" => :build

  def install
    system "zig", "build"
    bin.install "zig-out/bin/zc"
  end

  test do
    system "#{bin}/zc", "--help"
  end
end
