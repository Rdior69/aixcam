#!/bin/bash

# First-Time Setup and Commit Script
# Run this ONCE to set up your repository with all documentation

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  AIxcam Documentation Setup - First Run       ║${NC}"
echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
echo ""

echo -e "${BLUE}This script will:${NC}"
echo "  1. Make all scripts executable"
echo "  2. Review the new documentation files"
echo "  3. Commit everything to Git"
echo "  4. Push to GitHub"
echo ""

read -p "Continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Step 1: Make scripts executable
echo ""
echo -e "${BLUE}Step 1: Making scripts executable...${NC}"

chmod +x fix_duplicates.sh
chmod +x DELETE_DUPLICATES.sh
chmod +x git_sync.sh
chmod +x complete_sync.sh
chmod +x first_time_setup.sh

echo -e "${GREEN}✅ All scripts are now executable${NC}"

# Step 2: Show what's been created
echo ""
echo -e "${BLUE}Step 2: Documentation files created:${NC}"
echo ""

files=(
    "README.md"
    "CONTRIBUTING.md"
    "GIT_GUIDE.md"
    "SETUP_COMPLETE.md"
    "COMMIT_TEMPLATES.md"
    ".gitignore"
    "git_sync.sh"
    "complete_sync.sh"
    "first_time_setup.sh"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        lines=$(wc -l < "$file" 2>/dev/null || echo "0")
        size=$(ls -lh "$file" | awk '{print $5}')
        echo -e "${GREEN}  ✅${NC} $file ($lines lines, $size)"
    fi
done

echo ""
echo -e "${BLUE}Step 3: Quick overview${NC}"
echo ""
echo -e "${YELLOW}📖 README.md${NC}"
echo "   → Project overview and quick start guide"
echo ""
echo -e "${YELLOW}📖 SETUP_COMPLETE.md${NC}"
echo "   → Your main reference - start here!"
echo ""
echo -e "${YELLOW}📖 GIT_GUIDE.md${NC}"
echo "   → Quick Git command reference"
echo ""
echo -e "${YELLOW}📖 CONTRIBUTING.md${NC}"
echo "   → Detailed Git workflow and best practices"
echo ""
echo -e "${YELLOW}📖 COMMIT_TEMPLATES.md${NC}"
echo "   → Examples of good commit messages"
echo ""
echo -e "${YELLOW}🔧 git_sync.sh${NC}"
echo "   → Interactive Git operations tool"
echo ""
echo -e "${YELLOW}🔧 complete_sync.sh${NC}"
echo "   → All-in-one cleanup and sync workflow"
echo ""

# Step 4: Git check
echo ""
echo -e "${BLUE}Step 4: Git repository check${NC}"
echo ""

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Not a Git repository yet!${NC}"
    echo ""
    read -p "Initialize Git repository? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git init
        echo -e "${GREEN}✅ Git repository initialized${NC}"
    else
        echo ""
        echo "To initialize Git manually:"
        echo "  git init"
        echo "  git add ."
        echo "  git commit -m \"Initial commit with documentation\""
        echo "  git branch -M main"
        echo "  git remote add origin YOUR_GITHUB_URL"
        echo "  git push -u origin main"
        exit 0
    fi
fi

# Check for remote
if ! git remote get-url origin > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  No remote repository configured${NC}"
    echo ""
    read -p "Enter GitHub repository URL (or press Enter to skip): " remote_url
    
    if [ ! -z "$remote_url" ]; then
        git remote add origin "$remote_url"
        echo -e "${GREEN}✅ Remote added: $remote_url${NC}"
    else
        echo -e "${YELLOW}Skipped. You can add it later with:${NC}"
        echo "  git remote add origin YOUR_GITHUB_URL"
    fi
fi

# Step 5: Commit
echo ""
echo -e "${BLUE}Step 5: Commit documentation to Git${NC}"
echo ""

# Check if there are changes
if [[ -z $(git status --porcelain) ]]; then
    echo -e "${GREEN}✅ No changes to commit (already up to date)${NC}"
else
    echo "Files to commit:"
    git status --short | head -20
    echo ""
    
    read -p "Commit these files? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Add all new files
        git add .
        
        # Commit with comprehensive message
        git commit -m "Docs: Add comprehensive Git workflow system

Documentation:
- Added README.md with project overview
- Added CONTRIBUTING.md with detailed Git workflow
- Added GIT_GUIDE.md for quick reference
- Added SETUP_COMPLETE.md as quick start guide
- Added COMMIT_TEMPLATES.md with commit examples
- Added .gitignore for Xcode projects

Scripts:
- Added git_sync.sh for interactive Git operations
- Added complete_sync.sh for all-in-one workflow
- Updated fix_duplicates.sh with Git instructions
- Made all scripts executable

This establishes a consistent workflow for keeping
documentation synchronized across GitHub."

        echo ""
        echo -e "${GREEN}✅ Changes committed!${NC}"
        
        # Show the commit
        echo ""
        echo "Last commit:"
        git log --oneline -1
    else
        echo "Skipped commit. You can commit manually with:"
        echo "  git add ."
        echo "  git commit -m \"Docs: Add Git workflow system\""
        exit 0
    fi
fi

# Step 6: Push
echo ""
echo -e "${BLUE}Step 6: Push to GitHub${NC}"
echo ""

current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

if git remote get-url origin > /dev/null 2>&1; then
    read -p "Push to origin/$current_branch? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Try to push
        if git push -u origin "$current_branch" 2>&1; then
            echo ""
            echo -e "${GREEN}✅ Successfully pushed to GitHub!${NC}"
        else
            echo ""
            echo -e "${YELLOW}⚠️  Push failed. This might be because:${NC}"
            echo "  1. Remote repository doesn't exist yet"
            echo "  2. Authentication is needed"
            echo "  3. Branch needs to be created on remote"
            echo ""
            echo "Try pushing manually:"
            echo "  git push -u origin $current_branch"
        fi
    else
        echo "Skipped push. You can push manually with:"
        echo "  git push -u origin $current_branch"
    fi
else
    echo -e "${YELLOW}⚠️  No remote configured. Add one with:${NC}"
    echo "  git remote add origin YOUR_GITHUB_URL"
    echo "  git push -u origin $current_branch"
fi

# Final summary
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Setup Complete! 🎉                            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Your repository now has:${NC}"
echo "  ✅ Complete Git workflow documentation"
echo "  ✅ Automated sync scripts"
echo "  ✅ Commit message templates"
echo "  ✅ Quick reference guides"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo ""
echo "  1. Read SETUP_COMPLETE.md for quick start"
echo "  2. Bookmark GIT_GUIDE.md for daily use"
echo "  3. Use ./complete_sync.sh for future changes"
echo "  4. Share CONTRIBUTING.md with your team"
echo ""
echo -e "${YELLOW}Quick commands:${NC}"
echo ""
echo "  ./complete_sync.sh    # All-in-one cleanup and sync"
echo "  ./git_sync.sh         # Interactive Git operations"
echo "  ./fix_duplicates.sh   # Find duplicate files"
echo ""
echo -e "${GREEN}Happy coding! Your documentation will stay consistent! 🚀${NC}"
echo ""
