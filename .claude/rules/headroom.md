# Headroom — Context Compression Proxy

Headroom proxy at localhost:8787 compresses CC tool outputs by ~34%, extending effective context window. `ANTHROPIC_BASE_URL` is set automatically via a fish alias — no manual export needed when launching Claude Code from a fish shell.

## Shell Setup

**Fish** (configured in `~/.config/fish/config.fish`):

```fish
alias claude='ANTHROPIC_BASE_URL=http://127.0.0.1:8787 claude'
```

Reload with `source ~/.config/fish/config.fish` or open a new terminal.

**Bash/Zsh** (add to `~/.bashrc` or `~/.zshrc`):

```bash
export ANTHROPIC_BASE_URL=http://127.0.0.1:8787
```

## Troubleshooting

- If you see connection errors to the Anthropic API, Headroom proxy may have crashed. Check: `curl http://127.0.0.1:8787/health`
- To check token savings: `curl http://127.0.0.1:8787/stats`
- To restart manually: `headroom proxy --llmlingua-device cpu --port 8787 &`
- If Headroom is not installed, CC works normally — the proxy is optional

## Startup

- Terminal 1: `headroom proxy --llmlingua-device cpu --port 8787`
- Terminal 2: open a new terminal and run `claude` (`ANTHROPIC_BASE_URL` is set via shell config above)
