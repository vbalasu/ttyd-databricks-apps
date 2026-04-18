#!/usr/bin/env bash
set -euo pipefail

APP_DIR="databricks-ttyd-app"
APP_NAME="databricks-ttyd-app"

# ── Gather target environment info ──────────────────────────────────────────

echo "=== Databricks ttyd App Deployer ==="
echo ""

# Profile
read -rp "Databricks CLI profile name (or press Enter to list profiles): " PROFILE
if [[ -z "$PROFILE" ]]; then
    echo ""
    databricks auth profiles
    echo ""
    read -rp "Enter profile name: " PROFILE
fi

# Validate profile
if ! databricks auth profiles 2>/dev/null | grep -q "$PROFILE.*YES"; then
    echo ""
    echo "Profile '$PROFILE' is not valid or does not exist."
    read -rp "Workspace host URL (e.g. https://my-workspace.cloud.databricks.com): " HOST
    echo "Launching browser login..."
    databricks auth login "$HOST" --profile="$PROFILE"
fi
echo "Using profile: $PROFILE"

# Workspace username for upload path
read -rp "Workspace username/email (e.g. user@company.com): " USERNAME

# App name
read -rp "App name [$APP_NAME]: " CUSTOM_NAME
APP_NAME="${CUSTOM_NAME:-$APP_NAME}"

WORKSPACE_PATH="/Workspace/Users/${USERNAME}/${APP_NAME}"

echo ""
echo "── Deployment Plan ──"
echo "  Profile:        $PROFILE"
echo "  App name:       $APP_NAME"
echo "  Workspace path: $WORKSPACE_PATH"
echo ""
read -rp "Proceed? [Y/n] " CONFIRM
if [[ "${CONFIRM,,}" == "n" ]]; then
    echo "Aborted."
    exit 0
fi

# ── Ensure ttyd binary exists ───────────────────────────────────────────────

if [[ ! -f "$APP_DIR/ttyd" ]]; then
    echo ""
    echo "ttyd binary not found in $APP_DIR/. Downloading..."
    wget -O "$APP_DIR/ttyd" https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64
    chmod +x "$APP_DIR/ttyd"
fi

# ── Upload source code ──────────────────────────────────────────────────────

echo ""
echo "Uploading source code to $WORKSPACE_PATH ..."
databricks workspace import-dir "$APP_DIR" "${WORKSPACE_PATH#/Workspace}" \
    --profile="$PROFILE" --overwrite

# ── Create or reuse the app ─────────────────────────────────────────────────

echo ""
if databricks apps get "$APP_NAME" --profile="$PROFILE" &>/dev/null; then
    echo "App '$APP_NAME' already exists."
else
    echo "Creating app '$APP_NAME' ..."
    databricks apps create "$APP_NAME" \
        --description "Web-based terminal using ttyd" \
        --no-wait \
        --profile="$PROFILE"
fi

# ── Wait for compute to be ready ────────────────────────────────────────────

echo "Waiting for app compute to become ACTIVE ..."
for i in $(seq 1 60); do
    STATE=$(databricks apps get "$APP_NAME" --profile="$PROFILE" -o json 2>/dev/null \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('compute_status',{}).get('state','UNKNOWN'))")
    if [[ "$STATE" == "ACTIVE" ]]; then
        echo "Compute is ACTIVE."
        break
    fi
    if [[ $i -eq 60 ]]; then
        echo "ERROR: Timed out waiting for compute (5 min). Check the Databricks UI."
        exit 1
    fi
    printf "  [%02d/60] compute_state=%s\r" "$i" "$STATE"
    sleep 5
done

# ── Deploy ──────────────────────────────────────────────────────────────────

echo ""
echo "Deploying app ..."
databricks apps deploy "$APP_NAME" \
    --source-code-path "$WORKSPACE_PATH" \
    --no-wait \
    --profile="$PROFILE"

# ── Wait for deployment ─────────────────────────────────────────────────────

echo "Waiting for deployment to complete ..."
for i in $(seq 1 60); do
    RESULT=$(databricks apps get "$APP_NAME" --profile="$PROFILE" -o json 2>/dev/null)
    APP_STATE=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('app_status',{}).get('state','UNKNOWN'))")
    DEPLOY_STATE=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('active_deployment',{}).get('status',{}).get('state','UNKNOWN'))")

    if [[ "$APP_STATE" == "RUNNING" ]]; then
        APP_URL=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('url',''))")
        echo ""
        echo "=== Deployment successful! ==="
        echo "  App URL: $APP_URL"
        echo ""
        exit 0
    fi
    if [[ "$DEPLOY_STATE" == "FAILED" ]]; then
        MSG=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('active_deployment',{}).get('status',{}).get('message',''))")
        echo ""
        echo "ERROR: Deployment failed: $MSG"
        exit 1
    fi
    printf "  [%02d/60] app=%s deploy=%s\r" "$i" "$APP_STATE" "$DEPLOY_STATE"
    sleep 5
done

echo ""
echo "ERROR: Timed out waiting for deployment (5 min). Check the Databricks UI."
exit 1
