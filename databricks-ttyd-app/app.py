import os
import shutil
import stat
import subprocess
import sys


def check_tmux():
    """Check if tmux is installed, try to install if not."""
    if shutil.which("tmux"):
        return True

    print("tmux not found, attempting to install...")
    try:
        subprocess.run(
            ["apt-get", "install", "-y", "tmux"],
            check=True,
            capture_output=True,
            text=True,
        )
        if shutil.which("tmux"):
            print("tmux installed successfully.")
            return True
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"Could not install tmux: {e}")

    print("Continuing without tmux.")
    return False


def main():
    port = os.environ.get("DATABRICKS_APP_PORT", "8080")
    ttyd_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ttyd")

    if not os.path.isfile(ttyd_path):
        print(f"ERROR: ttyd binary not found at {ttyd_path}")
        print("Download it with:")
        print(f"  wget -O {ttyd_path} https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64")
        print(f"  chmod +x {ttyd_path}")
        sys.exit(1)

    # Ensure the binary is executable (workspace upload may strip permissions)
    os.chmod(ttyd_path, os.stat(ttyd_path).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    has_tmux = check_tmux()

    cmd = [ttyd_path, "--port", port, "--writable"]
    if has_tmux:
        cmd += ["tmux", "new-session", "-A", "-s", "main", "bash"]
    else:
        cmd.append("bash")

    mode = "tmux session" if has_tmux else "bash"
    print(f"Starting ttyd on port {port} with {mode}")
    print(f"Command: {' '.join(cmd)}")

    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        print(f"ttyd exited with error: {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nShutting down.")


if __name__ == "__main__":
    main()
