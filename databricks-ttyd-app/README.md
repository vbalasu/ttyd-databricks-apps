# Databricks ttyd App

A Databricks App that serves a web-based terminal using [ttyd](https://github.com/tsl0922/ttyd). Opens a fully interactive bash shell (with tmux session management when available) directly in your browser.

## How It Works

- The app launches the `ttyd` binary which serves a terminal over HTTP
- If `tmux` is available, it creates a persistent session named `main` so you can reconnect without losing state
- The port is read from `DATABRICKS_APP_PORT` (set automatically by Databricks Apps)

## Setup

### Download the ttyd binary

```bash
wget -O databricks-ttyd-app/ttyd https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64
chmod +x databricks-ttyd-app/ttyd
```

## Deploy

```bash
databricks apps deploy databricks-ttyd-app --source-code-path ./databricks-ttyd-app
```

## Access

After deployment, open the app from the Databricks UI:

1. Go to **Compute > Apps** in your Databricks workspace
2. Find `databricks-ttyd-app` in the list
3. Click the app name to open the web terminal
