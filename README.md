# zc

A lightweight network tool built with Zig.

## Installation

### Homebrew (macOS/Linux)

```bash
brew install ekil1100/tap/zc
```

Or manually tap:

```bash
brew tap ekil1100/tap https://github.com/ekil1100/homebrew-tap
brew install zc
```

### Debian/Ubuntu

```bash
wget https://github.com/ekil1100/zc/releases/download/v1.0.0-rc1/zc-v1.0.0-rc1-linux-amd64.tar.gz
tar -xzf zc-v1.0.0-rc1-linux-amd64.tar.gz
sudo cp zc-v1.0.0-rc1-linux-amd64/zc /usr/local/bin/
```

### From Release

```bash
curl -fsSL https://raw.githubusercontent.com/ekil1100/zc/main/scripts/install-curl.sh | bash
```

### Build from Source

Requires Zig 0.13.0+:

```bash
git clone https://github.com/ekil1100/zc
cd zc
zig build
```

## Quick Start

```bash
# Start TUI
zc tui

# Start service
zc start

# Check status
zc status
```

## License

MIT
