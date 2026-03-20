# Gclaw Agent Skill

This skill integrates **Gclaw — The Living Agent** into Seren Desktop, giving you an autonomous AI agent that trades DeFi to survive.

## What This Skill Provides

- Full installation and setup guidance for the Gclaw binary
- Configuration templates for LLM providers, DeFi trading, and channels
- Scripts for installation, verification, and testing
- Integration with the seren-skills ecosystem

## Source Repository

**https://github.com/GemachDAO/Gclaw**

Gclaw is an ultra-lightweight autonomous AI agent written in Go. It runs on `<10MB RAM`, boots in 1 second, and uses GMAC token metabolism — it must trade crypto to survive.

## Quick Start

```bash
# 1. Install Gclaw
bash scripts/install.sh

# 2. Initialize workspace
gclaw onboard

# 3. Configure (edit ~/.gclaw/config.json or set env vars)
cp .env.example .env
# edit .env with your API keys

# 4. Chat with your agent
gclaw agent -m "What is your GMAC balance?"

# 5. Start full gateway (web, channels, cron, health)
gclaw gateway
```

## Directory Layout

```
gemachdao/gclaw-agent/
├── SKILL.md                          # Full skill documentation (read this!)
├── README.md                         # This file
├── .env.example                      # Environment variable template
├── config.example.json               # Config.json template
├── .gitignore                        # Ignores config.json, .env, logs
└── scripts/
    ├── install.sh                    # Install Gclaw binary
    ├── verify.sh                     # Verify installation
    ├── smoke-test.sh                 # Quick live smoke test
    └── e2e-seren-integration.test.sh # Full E2E test suite
```

## License

MIT — see https://github.com/GemachDAO/Gclaw/blob/main/LICENSE
