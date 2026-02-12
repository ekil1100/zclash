# zc

A lightweight network tool built with Zig.

## Installation

### Homebrew (macOS/Linux)

```bash
brew tap ekil1100/zc https://github.com/ekil1100/zc
brew install zc
```

### Debian/Ubuntu

```bash
wget https://github.com/ekil1100/zc/releases/download/v1.0.0/zc_1.0.0_amd64.deb
sudo dpkg -i zc_1.0.0_amd64.deb
```

### From Release

```bash
curl -fsSL https://raw.githubusercontent.com/ekil1100/zc/main/scripts/install-curl.sh | bash
```

### Build from Source

Requires Zig 0.15.0+:

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
