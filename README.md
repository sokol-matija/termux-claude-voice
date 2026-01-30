# termux-claude-voice

One-command setup for Claude Code + VoiceMode on Android via Termux.

Uses your existing Kokoro (TTS) and Whisper (STT) services over Tailscale.

## Architecture

```
Android Phone (Termux)                  Remote Server (Tailscale)
┌──────────────────────┐                ┌──────────────────────┐
│  tmux session         │                │  Docker containers   │
│  └─ Claude Code       │   Tailscale   │  ├─ Kokoro (TTS:8880)│
│     └─ VoiceMode MCP  ├──────────────►│  └─ Whisper(STT:2022)│
│        ├─ mic input   │               └──────────────────────┘
│        └─ speaker/BT  │
└──────────────────────┘
```

## Prerequisites

- [Termux](https://f-droid.org/en/packages/com.termux/) installed from F-Droid (not Play Store)
- [Termux:API](https://f-droid.org/en/packages/com.termux.api/) addon from F-Droid
- [Tailscale](https://play.google.com/store/apps/details?id=com.tailscale.ipn) on your phone
- Kokoro TTS + Whisper STT running on a machine in your Tailscale network
- Anthropic API key for Claude Code

## Install

```bash
# Option 1: One-liner (will prompt for hostname)
curl -fsSL https://raw.githubusercontent.com/sokol-matija/termux-claude-voice/main/install.sh | bash

# Option 2: Pass hostname as argument via bash -s
curl -fsSL https://raw.githubusercontent.com/sokol-matija/termux-claude-voice/main/install.sh | bash -s sokol.falcon-parore.ts.net

# Option 3: Clone and run
git clone https://github.com/sokol-matija/termux-claude-voice.git
cd termux-claude-voice
bash install.sh sokol.falcon-parore.ts.net
```

## Usage

```bash
# Launch Claude Code with VoiceMode in tmux
cv

# Or full path
~/claude-voice

# Detach from tmux (keeps running)
# Press: Ctrl+B then D

# Reattach later
tmux attach -t claude-voice
```

## Configuration

### Environment Variables

Set before running `install.sh` to customize:

| Variable | Default | Description |
|---|---|---|
| `TAILSCALE_HOST` | _(prompted)_ | Your Tailscale hostname |
| `TTS_PORT` | `8880` | Kokoro TTS port |
| `STT_PORT` | `2022` | Whisper STT port |
| `VOICEMODE_VOICE` | `af_sky` | Default Kokoro voice |

### Config Files

- `~/.claude/settings.json` — Claude Code MCP config
- `~/.voicemode/voicemode.env` — VoiceMode environment
- `~/.config/pulse/default.pa` — PulseAudio config for Termux

## Troubleshooting

### No audio output
```bash
# Restart PulseAudio
pulseaudio --kill
pulseaudio --start --exit-idle-time=-1
```

### Can't reach Tailscale host
```bash
# Check Tailscale is connected
ping sokol.falcon-parore.ts.net
```

### Claude Code not found
```bash
# Reinstall
npm install -g @anthropic-ai/claude-code
```

## Uninstall

```bash
npm uninstall -g @anthropic-ai/claude-code
rm -rf ~/.voicemode ~/.claude/settings.json ~/claude-voice
```
