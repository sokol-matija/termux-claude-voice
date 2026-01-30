#!/data/data/com.termux/files/usr/bin/bash
# termux-claude-voice: One-command setup for Claude Code + VoiceMode on Termux
# Usage: curl -fsSL https://raw.githubusercontent.com/MatijaSokworkaround/termux-claude-voice/main/install.sh | bash
set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- Preflight ---
if [ ! -d "/data/data/com.termux" ]; then
  warn "Not running inside Termux. Some packages may differ."
fi

echo -e "${CYAN}"
echo "============================================"
echo "  Claude Code + VoiceMode for Termux"
echo "============================================"
echo -e "${NC}"

# --- Configuration ---
# Accept as: first argument, or env var, or interactive prompt
TAILSCALE_HOST="${1:-${TAILSCALE_HOST:-}}"
TTS_PORT="${TTS_PORT:-8880}"
STT_PORT="${STT_PORT:-2022}"
VOICEMODE_VOICE="${VOICEMODE_VOICE:-af_sky}"

if [ -z "$TAILSCALE_HOST" ]; then
  # Try interactive prompt, fall back to placeholder
  read -p "Enter your Tailscale hostname (e.g., sokol.falcon-parore.ts.net): " TAILSCALE_HOST < /dev/tty 2>/dev/null || true
fi

if [ -z "$TAILSCALE_HOST" ]; then
  TAILSCALE_HOST="YOUR_TAILSCALE_HOST"
  warn "No Tailscale host set. Using placeholder — edit ~/.claude/settings.json and ~/.voicemode/voicemode.env later."
fi

info "Tailscale host: $TAILSCALE_HOST"
info "TTS (Kokoro) port: $TTS_PORT"
info "STT (Whisper) port: $STT_PORT"
info "Voice: $VOICEMODE_VOICE"
echo ""

# --- Step 1: Update and install system packages ---
export DEBIAN_FRONTEND=noninteractive

info "Updating Termux packages..."
apt-get update -y && apt-get upgrade -y -o Dpkg::Options::="--force-confold"
ok "Packages updated"

info "Installing system dependencies..."
apt-get install -y -o Dpkg::Options::="--force-confold" \
  nodejs \
  python \
  python-pip \
  tmux \
  pulseaudio \
  git \
  openssh \
  termux-api \
  curl \
  wget
ok "System dependencies installed"

# --- Step 2: Install uv (Python package manager) ---
info "Installing uv..."
if command -v uv &> /dev/null; then
  ok "uv already installed"
else
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  ok "uv installed"
fi

# --- Step 3: Install Claude Code ---
info "Installing Claude Code..."
if command -v claude &> /dev/null; then
  ok "Claude Code already installed"
else
  npm install -g @anthropic-ai/claude-code
  ok "Claude Code installed"
fi

# --- Step 4: Configure VoiceMode MCP ---
info "Configuring VoiceMode MCP for Claude Code..."

CLAUDE_CONFIG_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_CONFIG_DIR"

# Write Claude Code settings with VoiceMode MCP
cat > "$CLAUDE_CONFIG_DIR/settings.json" << SETTINGSEOF
{
  "mcpServers": {
    "voicemode": {
      "command": "uvx",
      "args": ["--refresh", "voice-mode"],
      "env": {
        "VOICEMODE_TTS_BASE_URLS": "http://${TAILSCALE_HOST}:${TTS_PORT}/v1",
        "VOICEMODE_STT_BASE_URLS": "http://${TAILSCALE_HOST}:${STT_PORT}/v1",
        "VOICEMODE_VOICES": "${VOICEMODE_VOICE}"
      }
    }
  }
}
SETTINGSEOF
ok "VoiceMode MCP configured"

# --- Step 5: Configure VoiceMode env ---
info "Setting up VoiceMode environment..."

VOICEMODE_DIR="$HOME/.voicemode"
mkdir -p "$VOICEMODE_DIR"

cat > "$VOICEMODE_DIR/voicemode.env" << ENVEOF
# VoiceMode Configuration for Termux
# TTS (Kokoro) and STT (Whisper) via Tailscale
VOICEMODE_TTS_BASE_URLS=http://${TAILSCALE_HOST}:${TTS_PORT}/v1
VOICEMODE_STT_BASE_URLS=http://${TAILSCALE_HOST}:${STT_PORT}/v1
VOICEMODE_VOICES=${VOICEMODE_VOICE}
VOICEMODE_PREFER_LOCAL=true
VOICEMODE_ALWAYS_TRY_LOCAL=true
VOICEMODE_AUDIO_FEEDBACK=true
ENVEOF
ok "VoiceMode environment configured"

# --- Step 6: Setup PulseAudio for Termux ---
info "Configuring PulseAudio..."

# PulseAudio config for Termux audio access
PULSE_DIR="$HOME/.config/pulse"
mkdir -p "$PULSE_DIR"

cat > "$PULSE_DIR/default.pa" << PULSEEOF
.include /data/data/com.termux/files/usr/etc/pulse/default.pa
load-module module-sles-sink
load-module module-sles-source
PULSEEOF
ok "PulseAudio configured"

# --- Step 7: Create launcher script ---
info "Creating launcher script..."

cat > "$HOME/claude-voice" << 'LAUNCHEOF'
#!/data/data/com.termux/files/usr/bin/bash
# Launch Claude Code with VoiceMode in tmux

SESSION_NAME="claude-voice"

# Ensure PulseAudio is running
if ! pulseaudio --check 2>/dev/null; then
  pulseaudio --start --exit-idle-time=-1 2>/dev/null
  sleep 1
fi

# Check if session already exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "Attaching to existing session..."
  tmux attach-session -t "$SESSION_NAME"
else
  echo "Starting new Claude Voice session..."
  tmux new-session -d -s "$SESSION_NAME" -n claude
  tmux send-keys -t "$SESSION_NAME" 'claude' Enter
  tmux attach-session -t "$SESSION_NAME"
fi
LAUNCHEOF

chmod +x "$HOME/claude-voice"
ok "Launcher script created at ~/claude-voice"

# --- Step 8: Add PATH to shell profile ---
info "Updating shell profile..."

PROFILE="$HOME/.bashrc"
if ! grep -q '.local/bin' "$PROFILE" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$PROFILE"
fi

if ! grep -q 'alias cv=' "$PROFILE" 2>/dev/null; then
  echo 'alias cv="$HOME/claude-voice"' >> "$PROFILE"
fi

ok "Shell profile updated"

# --- Done ---
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Installation complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "  ${CYAN}Quick start:${NC}"
echo -e "    ${YELLOW}cv${NC}              - Launch Claude + VoiceMode in tmux"
echo -e "    ${YELLOW}~/claude-voice${NC}  - Same thing, full path"
echo ""
echo -e "  ${CYAN}Manual start:${NC}"
echo -e "    ${YELLOW}tmux new -s claude${NC}"
echo -e "    ${YELLOW}claude${NC}"
echo ""
echo -e "  ${CYAN}Tmux shortcuts:${NC}"
echo -e "    ${YELLOW}Ctrl+B D${NC}        - Detach (keeps running)"
echo -e "    ${YELLOW}tmux attach${NC}     - Reattach"
echo ""
echo -e "  ${CYAN}Config files:${NC}"
echo -e "    ~/.claude/settings.json"
echo -e "    ~/.voicemode/voicemode.env"
echo ""
echo -e "  ${CYAN}Tailscale host:${NC} $TAILSCALE_HOST"
echo -e "  ${CYAN}TTS (Kokoro):${NC}   port $TTS_PORT"
echo -e "  ${CYAN}STT (Whisper):${NC}  port $STT_PORT"
echo ""
info "Run 'source ~/.bashrc' or restart Termux, then type 'cv' to start!"
