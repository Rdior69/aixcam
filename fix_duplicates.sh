#!/bin/bash

# Script to find and help remove duplicate Swift files causing build errors
# Run this from your project root directory

echo "🔍 Searching for duplicate Swift files..."
echo ""

# Find all Swift files and their locations
echo "📁 All AuthTextField.swift files:"
find . -name "AuthTextField.swift" -not -path "*/DerivedData/*" -not -path "*/Build/*" -not -path "*/.build/*"
echo ""

echo "📁 All AppRouter.swift files:"
find . -name "AppRouter.swift" -not -path "*/DerivedData/*" -not -path "*/Build/*" -not -path "*/.build/*"
echo ""

echo "📁 All LiveBroadcastViewModel.swift files:"
find . -name "LiveBroadcastViewModel.swift" -not -path "*/DerivedData/*" -not -path "*/Build/*" -not -path "*/.build/*"
echo ""

echo "📁 All Package.swift files:"
find . -name "Package.swift" -not -path "*/DerivedData/*" -not -path "*/Build/*" -not -path "*/.build/*"
echo ""

echo "✅ Review the file locations above."
echo "🗑️  Remove duplicate files manually or through Xcode."
echo ""
echo "💡 After removing duplicates:"
echo "   1. Clean Build Folder: Xcode → Product → Clean Build Folder (Shift+Cmd+K)"
echo "   2. Delete Derived Data: rm -rf ~/Library/Developer/Xcode/DerivedData/AIxcam-*"
echo "   3. Rebuild: Xcode → Product → Build (Cmd+B)"
echo ""
echo "📚 Git Workflow (to sync with GitHub):"
echo "   1. Review changes: git status"
echo "   2. Stage changes: git add ."
echo "   3. Commit: git commit -m \"Fix: Remove duplicate Swift files\""
echo "   4. Pull latest: git pull origin main"
echo "   5. Push changes: git push origin main"
echo ""
echo "   Or use the automated script: ./git_sync.sh"
