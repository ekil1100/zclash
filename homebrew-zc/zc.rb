class Zc < Formula
  desc "Lightweight network tool built with Zig"
  homepage "https://github.com/ekil1100/zc"
  version "1.0.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/ekil1100/zc/releases/download/v#{version}/zc-v#{version}-macos-arm64.tar.gz"
      sha256 "PLACEHOLDER_SHA256_MACOS_ARM64"
    end
    on_intel do
      url "https://github.com/ekil1100/zc/releases/download/v#{version}/zc-v#{version}-macos-amd64.tar.gz"
      sha256 "PLACEHOLDER_SHA256_MACOS_AMD64"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/ekil1100/zc/releases/download/v#{version}/zc-v#{version}-linux-amd64.tar.gz"
      sha256 "PLACEHOLDER_SHA256_LINUX_AMD64"
    end
  end

  def install
    bin.install "zc"
  end

  test do
    system "#{bin}/zc", "--help"
  end
end
