#!/bin/bash

# Complete Cleanup and Sync Script for AIxcam
# This script handles duplicate cleanup, Xcode cleaning, and Git sync in one go

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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

print_info() {
    echo -e "${MAGENTA}ℹ️  $1${NC}"
}

# Banner
print_header "AIxcam Complete Cleanup & Sync"

echo "This script will:"
echo "  1. Check for duplicate Swift files"
echo "  2. Optionally remove duplicates"
echo "  3. Clean Xcode build artifacts"
echo "  4. Run a test build (optional)"
echo "  5. Commit and push changes to GitHub"
echo ""

read -p "Continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Cancelled by user"
    exit 0
fi

# Step 1: Check Git status
print_header "Step 1: Git Status Check"

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "Not a git repository!"
    exit 1
fi

current_branch=$(git rev-parse --abbrev-ref HEAD)
print_info "Current branch: $current_branch"

# Pull latest changes
print_step "Pulling latest changes from origin..."
if git pull origin "$current_branch" 2>&1; then
    print_success "Repository up to date"
else
    print_warning "Could not pull from origin (continuing anyway)"
fi

# Step 2: Check for duplicates
print_header "Step 2: Duplicate File Check"

files_to_check=("AuthTextField.swift" "AppRouter.swift" "LiveBroadcastViewModel.swift")
duplicates_found=false

for filename in "${files_to_check[@]}"; do
    file_count=$(find . -name "$filename" -not -path "*/DerivedData/*" -not -path "*/Build/*" -not -path "*/.build/*" 2>/dev/null | wc -l)
    
    if [ "$file_count" -gt 1 ]; then
        print_warning "$filename: Found $file_count copies"
        find . -name "$filename" -not -path "*/DerivedData/*" -not -path "*/Build/*" -not -path "*/.build/*" 2>/dev/null | while read file; do
            echo "     - $file"
        done
        duplicates_found=true
    elif [ "$file_count" -eq 1 ]; then
        print_success "$filename: OK (1 copy)"
    else
        print_info "$filename: Not found"
    fi
done

echo ""

if [ "$duplicates_found" = true ]; then
    echo -e "${YELLOW}Duplicates detected!${NC}"
    echo ""
    echo "Options:"
    echo "  1. Run DELETE_DUPLICATES.sh to remove them interactively"
    echo "  2. Skip duplicate removal and continue"
    echo "  3. Exit and handle manually"
    echo ""
    read -p "Choose (1-3): " dup_choice
    
    case $dup_choice in
        1)
            if [ -f "./DELETE_DUPLICATES.sh" ]; then
                print_step "Running DELETE_DUPLICATES.sh..."
                chmod +x DELETE_DUPLICATES.sh
                ./DELETE_DUPLICATES.sh
            else
                print_error "DELETE_DUPLICATES.sh not found"
                exit 1
            fi
            ;;
        2)
            print_info "Skipping duplicate removal"
            ;;
        3)
            print_info "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
else
    print_success "No duplicates found!"
fi

# Step 3: Clean Xcode
print_header "Step 3: Xcode Cleanup"

echo "Clean Xcode build artifacts?"
echo "  1. Clean DerivedData only"
echo "  2. Clean build folder (requires Xcode)"
echo "  3. Both"
echo "  4. Skip"
echo ""
read -p "Choose (1-4): " clean_choice

case $clean_choice in
    1|3)
        print_step "Cleaning DerivedData..."
        if rm -rf ~/Library/Developer/Xcode/DerivedData/AIxcam-* 2>/dev/null; then
            print_success "DerivedData cleaned"
        else
            print_warning "Could not clean DerivedData (may not exist)"
        fi
        ;&  # Fall through if option 3
    2)
        if [ "$clean_choice" = "2" ] || [ "$clean_choice" = "3" ]; then
            print_info "Clean Build Folder in Xcode:"
            print_info "  Product → Clean Build Folder (Shift+Cmd+K)"
            read -p "Press Enter when done (or Ctrl+C to skip)..."
        fi
        ;;
    4)
        print_info "Skipping Xcode cleanup"
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

# Step 4: Test build (optional)
print_header "Step 4: Test Build"

echo "Test build in Xcode before committing?"
echo "  1. Yes, I'll build now"
echo "  2. No, skip"
echo ""
read -p "Choose (1-2): " build_choice

if [ "$build_choice" = "1" ]; then
    print_info "Build the project in Xcode:"
    print_info "  Product → Build (Cmd+B)"
    echo ""
    read -p "Did the build succeed? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Build failed. Fix issues before committing."
        echo ""
        echo "You can still commit with: ./git_sync.sh"
        exit 1
    fi
    print_success "Build successful!"
fi

# Step 5: Check for changes
print_header "Step 5: Review Changes"

if [[ -z $(git status --porcelain) ]]; then
    print_success "No changes to commit"
    echo ""
    print_info "Everything is up to date!"
    exit 0
fi

print_step "Changed files:"
git status --short
echo ""

read -p "Review these changes? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    git status
    echo ""
    git diff --stat
    echo ""
fi

# Step 6: Commit changes
print_header "Step 6: Commit Changes"

echo "Suggested commit messages:"
echo "  1. Fix: Remove duplicate Swift files"
echo "  2. Docs: Update documentation"
echo "  3. Chore: Clean up project structure"
echo "  4. Custom message"
echo ""
read -p "Choose (1-4): " commit_choice

case $commit_choice in
    1)
        commit_message="Fix: Remove duplicate Swift files

- Cleaned up duplicate AuthTextField.swift
- Cleaned up duplicate AppRouter.swift
- Cleaned up duplicate LiveBroadcastViewModel.swift
- Updated build configuration"
        ;;
    2)
        commit_message="Docs: Update documentation

- Updated build instructions
- Updated Git workflow guide
- Added cleanup scripts"
        ;;
    3)
        commit_message="Chore: Clean up project structure

- Removed duplicate files
- Cleaned build artifacts
- Updated documentation"
        ;;
    4)
        echo ""
        read -p "Enter commit message: " custom_message
        
        if [ -z "$custom_message" ]; then
            print_error "Commit message cannot be empty"
            exit 1
        fi
        
        commit_message="$custom_message"
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

echo ""
print_info "Commit message:"
echo -e "${CYAN}$commit_message${NC}"
echo ""
read -p "Use this message? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Commit cancelled"
    echo ""
    echo "You can manually commit with:"
    echo "  git add ."
    echo "  git commit -m \"Your message\""
    echo "  git push origin $current_branch"
    exit 0
fi

# Stage changes
print_step "Staging all changes..."
git add .
print_success "Changes staged"

# Commit
print_step "Committing..."
if git commit -m "$commit_message"; then
    print_success "Changes committed"
else
    print_error "Commit failed"
    exit 1
fi

# Step 7: Push to GitHub
print_header "Step 7: Push to GitHub"

print_step "Pushing to origin/$current_branch..."

if git push origin "$current_branch"; then
    print_success "Successfully pushed to GitHub!"
else
    print_error "Push failed"
    echo ""
    echo "You may need to:"
    echo "  1. Check your internet connection"
    echo "  2. Verify GitHub credentials"
    echo "  3. Pull latest changes first: git pull origin $current_branch"
    exit 1
fi

# Final summary
print_header "🎉 Complete!"

print_success "All steps completed successfully!"
echo ""
echo "Summary:"
echo "  ✓ Checked for duplicates"
echo "  ✓ Cleaned Xcode artifacts"
echo "  ✓ Committed changes"
echo "  ✓ Pushed to GitHub ($current_branch)"
echo ""
print_info "Your documentation is now consistent on GitHub!"
echo ""

# Show final status
print_step "Final repository status:"
git log --oneline -3
echo ""
