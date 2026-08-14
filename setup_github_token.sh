#!/bin/bash

# GitHub Token Setup Script
# Helps configure Git to use your Personal Access Token

set -e

echo "🔐 GitHub Token Setup"
echo "===================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}This script will help you configure Git to use your GitHub Personal Access Token.${NC}"
echo ""
echo "First, make sure you have created a token at:"
echo "https://github.com/settings/tokens"
echo ""
echo "Required token scopes:"
echo "  - repo (all)"
echo "  - workflow"
e                                                                         cho "  - write:packages"
echo "  - read:packages"
echo ""

# Check current Git credential helper
echo -e "${BLUE}Current credential helper:${NC}"
git config --global credential.helper || echo "None set"
echo ""

echo "Choose a credential storage method:"
echo ""
echo "1. macOS Keychain (Recommended for Mac)"
echo "2. Cache in memory (15 minutes)"
echo "3. Cache in memory (1 hour)"
echo "4. Store in plaintext file (NOT RECOMMENDED - insecure)"
echo "5. Manual entry each time (no caching)"
echo ""

read -p "Enter your choice (1-5): " choice
echo ""

case $choice in
    1)
        echo -e "${GREEN}Setting up macOS Keychain storage...${NC}"
        git config --global credential.helper osxkeychain
        echo -e "${GREEN}✅ Configured to use macOS Keychain${NC}"
        echo ""
        echo "Next time you push/pull, enter:"
        echo "  Username: your-github-username"
        echo "  Password: your-github-token (starts with ghp_)"
        echo ""
        echo "Your token will be saved in Keychain and you won't need to enter it again."
        ;;
    2)
        echo -e "${GREEN}Setting up 15-minute memory cache...${NC}"
        git config --global credential.helper 'cache --timeout=900'
        echo -e "${GREEN}✅ Configured to cache credentials for 15 minutes${NC}"
        ;;
    3)
        echo -e "${GREEN}Setting up 1-hour memory cache...${NC}"
        git config --global credential.helper 'cache --timeout=3600'
        echo -e "${GREEN}✅ Configured to cache credentials for 1 hour${NC}"
        ;;
    4)
        echo -e "${YELLOW}⚠️  WARNING: This stores your token in PLAINTEXT!${NC}"
        read -p "Are you sure? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git config --global credential.helper store
            echo -e "${YELLOW}✅ Configured to store credentials (plaintext)${NC}"
        else
            echo "Cancelled."
            exit 0
        fi
        ;;
    5)
        echo -e "${BLUE}Removing credential helper...${NC}"
        git config --global --unset credential.helper || true
        echo -e "${GREEN}✅ You'll need to enter credentials each time${NC}"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo -e "${BLUE}📋 Testing Your Setup${NC}"
echo "=========================================="
echo ""
echo "You can test your token with:"
echo ""
echo "  git ls-remote https://github.com/yourusername/AIxcam.git"
echo ""
echo "Or try a push/pull:"
echo ""
echo "  git pull origin main"
echo ""
echo -e "${YELLOW}Remember:${NC}"
echo "  - Username: your GitHub username"
echo "  - Password: your token (ghp_...)"
echo "  - DO NOT use your GitHub password!"
echo ""

echo "=========================================="
echo -e "${BLUE}📋 Token Management${NC}"
echo "=========================================="
echo ""
echo "To create a new token:"
echo "  https://github.com/settings/tokens"
echo ""
echo "To remove stored credentials:"
echo "  - Keychain: Open Keychain Access app → Search 'github'"
echo "  - Store: rm ~/.git-credentials"
echo "  - Cache: Wait for timeout or restart terminal"
echo ""

echo "✅ Done!"
echo ""
