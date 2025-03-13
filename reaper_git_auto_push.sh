#!/bin/bash

REPO_PATH="/Users/jonathankawchuk/Library/Application Support/REAPER"
BRANCH="main"  # Change if using a different branch
LOG_FILE="$HOME/reaper_git_log.txt"

# Check if the directory exists
if [ ! -d "$REPO_PATH/.git" ]; then
    echo "Not a Git repository. Initialize it first." | tee -a "$LOG_FILE"
    exit 1
fi

cd "$REPO_PATH" || exit

# Add, commit, and push
git add .
if git commit -m "Automated commit - $(date)"; then
    if git push origin "$BRANCH"; then
        echo "Push successful at $(date)" >> "$LOG_FILE"
    else
        echo "Push failed at $(date), will retry on startup" >> "$LOG_FILE"
        touch "$HOME/reaper_git_failed"
    fi
else
    echo "No changes to commit at $(date)" >> "$LOG_FILE"
fi
