#!/bin/bash

# Firebase Package Fix Script
# This removes conflicting Package.swift and provides instructions

set -e

echo "🔧 Firebase Package Fix"
echo "======================="
echo ""
echo "Your project has both Package.swift and .xcodeproj, causing conflicts."
echo "For an iOS app, you should use .xcodeproj with SPM dependencies."
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Package.swift exists
if [ -f "Package.swift" ]; then
    echo -e "${YELLOW}Found Package.swift${NC}"
    echo ""
    echo "This file conflicts with your Xcode project setup."
    echo ""
    read -p "Remove Package.swift? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mv Package.swift Package.swift.backup
        echo -e "${GREEN}✅ Moved Package.swift to Package.swift.backup${NC}"
        echo ""
    else
        echo -e "${YELLOW}Skipped - you'll need to remove it manually${NC}"
        echo ""
    fi
else
    echo -e "${YELLOW}Package.swift not found in current directory${NC}"
    echo ""
fi

# Clean DerivedData
echo -e "${BLUE}Cleaning DerivedData...${NC}"
rm -rf ~/Library/Developer/Xcode/DerivedData/AIxcam-*
echo -e "${GREEN}✅ DerivedData cleaned${NC}"
echo ""

echo "=========================================="
echo -e "${BLUE}📋 Next Steps in Xcode${NC}"
echo "=========================================="
echo ""
echo "1. Open AIxcam.xcodeproj in Xcode"
echo ""
echo "2. Add Firebase Package Dependency:"
echo "   a. Click on project in navigator"
echo "   b. Select your app target"
echo "   c. Click 'Package Dependencies' tab"
echo "   d. Click '+' button"
echo "   e. Enter: https://github.com/firebase/firebase-ios-sdk"
echo "   f. Click 'Add Package'"
echo "   g. Select: FirebaseAuth, FirebaseCore"
echo "   h. Click 'Add Package'"
echo ""
echo "3. Clean Build Folder:"
echo "   Product → Clean Build Folder (Shift+Cmd+K)"
echo ""
echo "4. Build:"
echo "   Product → Build (Cmd+B)"
echo ""
echo "✅ Done!"
echo ""
