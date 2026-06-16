#!/usr/bin/env bash
set -euo pipefail

OS="$(uname -s)"
ARCH="$(uname -m)"

echo "detected: $OS / $ARCH"
echo ""
echo "this will install:"
echo "  - Go"
echo "  - gopls, goimports, dlv, golangci-lint, govulncheck"
echo ""
read -rp "continue? (y/n): " CONFIRM
[[ "$CONFIRM" != "y" ]] && echo "cancelled." && exit 0
echo ""

install_go_macos() {
    if ! command -v brew &>/dev/null; then
        echo "installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    echo "installing Go via brew..."
    brew install go
}

install_go_linux() {
    GO_VERSION="$(curl -fsSL https://go.dev/VERSION?m=text | head -1)"

    case "$ARCH" in
        x86_64)  GOARCH="amd64" ;;
        aarch64) GOARCH="arm64" ;;
        armv6l)  GOARCH="armv6l" ;;
        *)       echo "error: unsupported architecture: $ARCH" && exit 1 ;;
    esac

    TARBALL="${GO_VERSION}.linux-${GOARCH}.tar.gz"
    echo "downloading ${TARBALL}..."
    curl -fsSL "https://go.dev/dl/${TARBALL}" -o /tmp/go.tar.gz

    echo "installing to /usr/local/go..."
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    rm /tmp/go.tar.gz

    SHELL_RC="$HOME/.bashrc"
    [[ "$SHELL" == */zsh ]] && SHELL_RC="$HOME/.zshrc"

    if ! grep -q '/usr/local/go/bin' "$SHELL_RC" 2>/dev/null; then
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> "$SHELL_RC"
        echo "added Go to PATH in $SHELL_RC"
    fi

    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
}

case "$OS" in
    Darwin) install_go_macos ;;
    Linux)  install_go_linux ;;
    *)      echo "error: unsupported OS: $OS" && exit 1 ;;
esac

echo ""
echo "installing global tools..."
go install golang.org/x/tools/gopls@latest
go install golang.org/x/tools/cmd/goimports@latest
go install github.com/go-delve/delve/cmd/dlv@latest
go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
go install golang.org/x/vuln/cmd/govulncheck@latest

echo ""
echo "done."
echo ""
echo "  restart your terminal, then run: go version"
