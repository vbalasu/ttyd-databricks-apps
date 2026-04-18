# ttyd Databricks App

A Databricks App that serves a web-based terminal using [ttyd](https://github.com/tsl0922/ttyd). Opens a fully interactive bash shell directly in your browser, with optional tmux session persistence.

## Quick Start

```bash
# Clone the repo
git clone git@github.com:vbalasu/ttyd-databricks-apps.git
cd ttyd-databricks-apps

# Deploy to any Databricks workspace
./deploy.sh
```

The deploy script will prompt you for:
- **Databricks CLI profile** — select from existing profiles or create a new one
- **Workspace username/email** — used for the upload path
- **App name** — defaults to `databricks-ttyd-app`

It handles everything else: downloading the ttyd binary, uploading source code, creating the app, and waiting for it to go live.

## Manual Setup

If you prefer to deploy manually:

```bash
# Download the ttyd binary
wget -O databricks-ttyd-app/ttyd https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64
chmod +x databricks-ttyd-app/ttyd

# Upload to your workspace
databricks workspace import-dir databricks-ttyd-app \
  /Users/<your-email>/databricks-ttyd-app \
  --profile=<profile> --overwrite

# Create and deploy the app
databricks apps create databricks-ttyd-app --profile=<profile>
databricks apps deploy databricks-ttyd-app \
  --source-code-path /Workspace/Users/<your-email>/databricks-ttyd-app \
  --profile=<profile>
```

## How It Works

- `app.py` reads the port from `DATABRICKS_APP_PORT` (set automatically by Databricks)
- Ensures the ttyd binary is executable at startup
- If tmux is available, launches a persistent session so you can reconnect without losing state
- Otherwise falls back to a plain bash shell

## Project Structure

```
├── databricks-ttyd-app/
│   ├── app.py              # Entry point — launches ttyd
│   ├── app.yaml            # Databricks Apps config
│   ├── requirements.txt    # Python deps (none needed)
│   └── ttyd                # Static binary (downloaded by deploy.sh)
├── deploy.sh               # One-command deployment script
└── README.md
```
