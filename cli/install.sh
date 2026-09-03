#!/usr/bin/env bash
# ==============================================================================
# AiBL Author CLI - Automated Standalone Installer for macOS & Linux
# ==============================================================================
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/opmediainc/aibl-author/main/scripts/install.sh | bash
# ==============================================================================

set -euo pipefail

# ANSI color codes
BOLD="\033[1m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
DIM="\033[2m"
RESET="\033[0m"

AIBL_HOME="${HOME}/.aibl"
RUNTIME_DIR="${AIBL_HOME}/runtime"
NODE_DIR="${RUNTIME_DIR}/node"
AIBL_BIN_DIR="${AIBL_HOME}/bin"
LOCAL_BIN_DIR="${HOME}/.local/bin"
NODE_VERSION="v22.14.0"
PACKAGE_NAME="@op-media-inc/aibl-author-cli"

print_banner() {
  cat << "EOF"

    ___      _   ____   __         ___             __     __                
   /   |    (_) / __ ) / /        /   |  __  __   / /_   / /_   ____   _____
  / /| |   / / / __  |/ /        / /| | / / / /  / __/  / __ \ / __ \ / ___/
 / ___ |  / / / /_/ // /___     / ___ |/ /_/ /  / /_   / / / // /_/ // /    
/_/  |_| /_/ /_____//_____/    /_/  |_|\__,_/   \__/  /_/ /_/ \____//_/     
                                                                            
EOF
  echo -e "${BOLD}AiBL Author CLI & MCP Automated Installer${RESET}"
  echo -e "${DIM}https://demo.aiblx.ai${RESET}\n"
}

info() {
  echo -e "${CYAN}ℹ${RESET} $1"
}

success() {
  echo -e "${GREEN}✔${RESET} $1"
}

warn() {
  echo -e "${YELLOW}▲${RESET} $1"
}

error() {
  echo -e "${RED}✖${RESET} $1" >&2
}

# 1. Check Platform & Architecture
detect_platform() {
  local os_type
  os_type="$(uname -s)"
  case "${os_type}" in
    Darwin)
      OS="darwin"
      ;;
    Linux)
      OS="linux"
      ;;
    *)
      error "Unsupported operating system: ${os_type}"
      echo "This installation script supports macOS (Darwin) and Linux."
      echo "For Windows, please use npm: npm install -g ${PACKAGE_NAME}@latest"
      exit 1
      ;;
  esac

  local arch_type
  arch_type="$(uname -m)"
  case "${arch_type}" in
    x86_64|amd64)
      ARCH="x64"
      ;;
    arm64|aarch64)
      ARCH="arm64"
      ;;
    *)
      error "Unsupported CPU architecture: ${arch_type}"
      exit 1
      ;;
  esac

  info "Detected platform: ${BOLD}${OS}-${ARCH}${RESET}"
}

# 2. Provision Isolated Node.js Runtime
RUNTIME_TYPE="isolated"
setup_node_runtime() {
  mkdir -p "${AIBL_HOME}" "${RUNTIME_DIR}" "${AIBL_BIN_DIR}" "${LOCAL_BIN_DIR}"

  local node_binary="${NODE_DIR}/bin/node"
  local need_download=true

  if [ -x "${node_binary}" ]; then
    local installed_ver
    installed_ver="$("${node_binary}" -v 2>/dev/null || echo "")"
    if [ "${installed_ver}" = "${NODE_VERSION}" ]; then
      info "Standalone Node.js LTS (${NODE_VERSION}) runtime already provisioned."
      RUNTIME_TYPE="existing"
      need_download=false
    fi
  fi

  if [ "${need_download}" = true ]; then
    info "Provisioning isolated Node.js runtime (${NODE_VERSION}) into ${DIM}${NODE_DIR}${RESET}..."
    local tarball_name="node-${NODE_VERSION}-${OS}-${ARCH}.tar.gz"
    local download_url="https://nodejs.org/dist/${NODE_VERSION}/${tarball_name}"

    local temp_tar="/tmp/${tarball_name}.$$"
    
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL --progress-bar "${download_url}" -o "${temp_tar}"
    elif command -v wget >/dev/null 2>&1; then
      wget -q --show-progress "${download_url}" -O "${temp_tar}"
    else
      error "Neither curl nor wget was found on your system. Please install curl or wget first."
      exit 1
    fi

    rm -rf "${NODE_DIR}"
    mkdir -p "${NODE_DIR}"
    tar -xzf "${temp_tar}" -C "${NODE_DIR}" --strip-components=1
    rm -f "${temp_tar}"
    success "Node.js runtime provisioned successfully."
    RUNTIME_TYPE="isolated"
  fi
}

# 3. Install or Update AIBL Author CLI Package
install_cli() {
  local runtime_type="${1:-${RUNTIME_TYPE}}"
  info "Installing ${BOLD}${PACKAGE_NAME}${RESET} in ${runtime_type} runtime..."
  local npm_binary="${NODE_DIR}/bin/npm"

  "${npm_binary}" install -g --prefix "${RUNTIME_DIR}" "${PACKAGE_NAME}@latest" --silent --no-audit --no-fund >/dev/null 2>&1 || {
    # If silent fails, rerun with output for troubleshooting
    "${npm_binary}" install -g --prefix "${RUNTIME_DIR}" "${PACKAGE_NAME}@latest"
  }

  success "AiBL Author CLI installed."
}

# 4. Create Wrapper Executable & Symlinks
setup_executables() {
  local wrapper="${AIBL_BIN_DIR}/aibl"
  cat << 'EOF' > "${wrapper}"
#!/usr/bin/env bash
AIBL_DIR="${HOME}/.aibl"
NODE_BIN="${AIBL_DIR}/runtime/node/bin/node"
CLI_ENTRY="${AIBL_DIR}/runtime/lib/node_modules/@op-media-inc/aibl-author-cli/dist/index.js"

export PATH="${AIBL_DIR}/runtime/node/bin:${AIBL_DIR}/bin:${PATH}"

if [ -f "${CLI_ENTRY}" ]; then
  exec "${NODE_BIN}" "${CLI_ENTRY}" "$@"
elif [ -f "${AIBL_DIR}/runtime/bin/aibl" ]; then
  exec "${AIBL_DIR}/runtime/bin/aibl" "$@"
else
  echo "Error: AiBL Author CLI executable not found in ${AIBL_DIR}/runtime." >&2
  exit 1
fi
EOF

  chmod +x "${wrapper}"
  
  # Symlink to ~/.local/bin/aibl and ~/.local/bin/aibl-author-cli
  ln -sf "${wrapper}" "${LOCAL_BIN_DIR}/aibl"
  ln -sf "${wrapper}" "${LOCAL_BIN_DIR}/aibl-author-cli"

  success "Executable wrappers configured in ${DIM}${AIBL_BIN_DIR}${RESET} and ${DIM}${LOCAL_BIN_DIR}${RESET}"
}

# 5. Shell PATH Configuration
configure_shell_path() {
  local path_line='export PATH="${HOME}/.local/bin:${HOME}/.aibl/bin:${PATH}"'
  local updated_profiles=()

  # Check ZSH
  if [ -f "${HOME}/.zshrc" ]; then
    if ! grep -q '\.aibl/bin' "${HOME}/.zshrc" && ! grep -q '\.local/bin' "${HOME}/.zshrc"; then
      echo -e "\n# AiBL Author CLI\n${path_line}" >> "${HOME}/.zshrc"
      updated_profiles+=("~/.zshrc")
    fi
  elif [ "${SHELL:-}" = "*/zsh" ]; then
    echo -e "# AiBL Author CLI\n${path_line}" >> "${HOME}/.zshrc"
    updated_profiles+=("~/.zshrc")
  fi

  # Check Bash
  if [ -f "${HOME}/.bashrc" ]; then
    if ! grep -q '\.aibl/bin' "${HOME}/.bashrc" && ! grep -q '\.local/bin' "${HOME}/.bashrc"; then
      echo -e "\n# AiBL Author CLI\n${path_line}" >> "${HOME}/.bashrc"
      updated_profiles+=("~/.bashrc")
    fi
  fi

  if [ -f "${HOME}/.bash_profile" ]; then
    if ! grep -q '\.aibl/bin' "${HOME}/.bash_profile" && ! grep -q '\.local/bin' "${HOME}/.bash_profile"; then
      echo -e "\n# AiBL Author CLI\n${path_line}" >> "${HOME}/.bash_profile"
      updated_profiles+=("~/.bash_profile")
    fi
  fi

  # Check Fish
  if [ -d "${HOME}/.config/fish" ]; then
    local fish_config="${HOME}/.config/fish/config.fish"
    if [ -f "${fish_config}" ]; then
      if ! grep -q '\.aibl/bin' "${fish_config}"; then
        echo -e "\n# AiBL Author CLI\nfish_add_path ~/.local/bin ~/.aibl/bin" >> "${fish_config}"
        updated_profiles+=("~/.config/fish/config.fish")
      fi
    fi
  fi

  if [ ${#updated_profiles[@]} -gt 0 ]; then
    info "Updated PATH in: ${BOLD}${updated_profiles[*]}${RESET}"
  fi
}

# 6. Automated Claude Desktop Setup
configure_claude_desktop() {
  local claude_config=""
  if [ "${OS}" = "darwin" ] && [ -d "${HOME}/Library/Application Support/Claude" ]; then
    claude_config="${HOME}/Library/Application Support/Claude/claude_desktop_config.json"
  elif [ "${OS}" = "linux" ] && [ -d "${HOME}/.config/Claude" ]; then
    claude_config="${HOME}/.config/Claude/claude_desktop_config.json"
  fi

  if [ -n "${claude_config}" ]; then
    info "Detected Claude Desktop installation. Configuring AiBL MCP bridge..."
    "${AIBL_BIN_DIR}/aibl" mcp setup claude-desktop --force >/dev/null 2>&1 || true
    success "Claude Desktop MCP bridge configured."
  fi
}

main() {
  print_banner
  detect_platform
  setup_node_runtime
  install_cli
  setup_executables
  configure_shell_path
  configure_claude_desktop

  echo -e "\n======================================================"
  echo -e "       ${GREEN}${BOLD}AiBL Author CLI Setup Complete!${RESET}"
  echo -e "======================================================\n"
  
  local version
  version="$("${AIBL_BIN_DIR}/aibl" --version 2>/dev/null || echo "1.0.3")"
  echo -e "  • Installed Version : ${BOLD}v${version}${RESET}"
  echo -e "  • Default Context   : ${CYAN}cloud${RESET} (${BOLD}https://demo.aiblx.ai${RESET})"
  echo -e "  • Executable Path   : ${DIM}${LOCAL_BIN_DIR}/aibl${RESET}\n"

  echo -e "${BOLD}Next Steps:${RESET}"
  echo -e "  1. Authenticate with your AiBL account:"
  echo -e "     ${CYAN}aibl auth${RESET}\n"
  echo -e "  2. (Optional) If Claude Desktop was open, quit completely (${BOLD}Cmd+Q${RESET}) and reopen it.\n"
  echo -e "  3. If '${CYAN}aibl${RESET}' command is not found in your current terminal, reload your shell:"
  echo -e "     ${DIM}source ~/.zshrc${RESET}  or  ${DIM}source ~/.bashrc${RESET}\n"
}

main "$@"
