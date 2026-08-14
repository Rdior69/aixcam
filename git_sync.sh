#!/bin/bash

# Git Sync Script for AIxcam
# Automates common Git operations to keep repository consistent

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get the project directory
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$PROJECT_DIR"

# Functions
print_header() {
    echo ""
    echo -e "${CYAN}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "Not a git repository!"
    echo ""
    echo "Initialize with: git init"
    exit 1
fi

# Main Menu
print_header "AIxcam Git Sync Tool"

echo "What would you like to do?"
echo ""
echo "1) Quick commit and push (current branch)"
echo "2) Pull latest changes from GitHub"
echo "3) Full sync (pull, commit, push)"
echo "4) Create new feature branch"
echo "5) View status and recent commits"
echo "6) Sync documentation only"
echo "7) Exit"
echo ""
read -p "Choose an option (1-7): " choice

case $choice in
    1)
        # Quick commit and push
        print_header "Quick Commit and Push"
        
        # Show status
        print_step "Current changes:"
        git status --short
        echo ""
        
        # Check if there are changes
        if [[ -z $(git status --porcelain) ]]; then
            print_warning "No changes to commit"
            exit 0
        fi
        
        # Get commit message
        read -p "Enter commit message: " commit_message
        
        if [ -z "$commit_message" ]; then
            print_error "Commit message cannot be empty"
            exit 1
        fi
        
        # Stage all changes
        print_step "Staging changes..."
        git add .
        print_success "Changes staged"
        
        # Commit
        print_step "Committing..."
        git commit -m "$commit_message"
        print_success "Changes committed"
        
        # Get current branch
        current_branch=$(git rev-parse --abbrev-ref HEAD)
        
        # Push
        print_step "Pushing to origin/$current_branch..."
        git push origin "$current_branch"
        print_success "Changes pushed to GitHub!"
        ;;
        
    2)
        # Pull latest changes
        print_header "Pull Latest Changes"
        
        current_branch=$(git rev-parse --abbrev-ref HEAD)
        
        print_step "Fetching from origin..."
        git fetch origin
        
        print_step "Pulling latest changes for $current_branch..."
        git pull origin "$current_branch"
        
        print_success "Repository updated!"
        ;;
        
    3)
        # Full sync
        print_header "Full Repository Sync"
        
        current_branch=$(git rev-parse --abbrev-ref HEAD)
        
        # Pull first
        print_step "Pulling latest changes..."
        git fetch origin
        
        if git diff --quiet origin/"$current_branch" "$current_branch"; then
            print_success "Already up to date with origin"
        else
            git pull origin "$current_branch"
            print_success "Pulled latest changes"
        fi
        
        # Check for local changes
        if [[ -z $(git status --porcelain) ]]; then
            print_success "No local changes to commit"
            exit 0
        fi
        
        # Show changes
        print_step "Local changes:"
        git status --short
        echo ""
        
        # Commit
        read -p "Enter commit message: " commit_message
        
        if [ -z "$commit_message" ]; then
            print_error "Commit message cannot be empty"
            exit 1
        fi
        
        git add .
        git commit -m "$commit_message"
        print_success "Changes committed"
        
        # Push
        print_step "Pushing to origin/$current_branch..."
        git push origin "$current_branch"
        print_success "Full sync complete!"
        ;;
        
    4)
        # Create feature branch
        print_header "Create Feature Branch"
        
        print_step "Current branches:"
        git branch
        echo ""
        
        read -p "Enter new branch name (e.g., feature/new-feature): " branch_name
        
        if [ -z "$branch_name" ]; then
            print_error "Branch name cannot be empty"
            exit 1
        fi
        
        # Pull latest from main
        print_step "Pulling latest from main..."
        git checkout main 2>/dev/null || git checkout master 2>/dev/null || true
        git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
        
        # Create and switch to new branch
        print_step "Creating branch: $branch_name"
        git checkout -b "$branch_name"
        
        print_success "Branch created and checked out!"
        echo ""
        echo "You can now make changes and commit them."
        echo "When ready, use option 1 to commit and push."
        ;;
        
    5)
        # View status
        print_header "Repository Status"
        
        current_branch=$(git rev-parse --abbrev-ref HEAD)
        
        print_step "Current branch: $current_branch"
        echo ""
        
        print_step "Local changes:"
        git status
        echo ""
        
        print_step "Recent commits:"
        git log --oneline -10
        echo ""
        
        print_step "Remote branches:"
        git branch -r
        ;;
        
    6)
        # Sync documentation only
        print_header "Sync Documentation"
        
        print_step "Checking for documentation changes..."
        
        # Add only documentation files
        git add *.md *.sh README* CONTRIBUTING* docs/ 2>/dev/null || true
        
        if [[ -z $(git diff --cached --name-only) ]]; then
            print_warning "No documentation changes to commit"
            exit 0
        fi
        
        print_step "Files to commit:"
        git diff --cached --name-only
        echo ""
        
        read -p "Enter commit message (default: 'Docs: Update documentation'): " commit_message
        
        if [ -z "$commit_message" ]; then
            commit_message="Docs: Update documentation"
        fi
        
        git commit -m "$commit_message"
        print_success "Documentation committed"
        
        current_branch=$(git rev-parse --abbrev-ref HEAD)
        
        print_step "Pushing to origin/$current_branch..."
        git push origin "$current_branch"
        print_success "Documentation synced to GitHub!"
        ;;
        
    7)
        # Exit
        print_success "Goodbye!"
        exit 0
        ;;
        
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

echo ""
print_success "Operation complete!"
echo ""
