#!/bin/bash

# AIxcam Duplicate File Deletion Script
# This script will AUTOMATICALLY DELETE duplicate files
# WARNING: This will permanently delete files. Review carefully before running!

set -e

echo "🗑️  AIxcam Duplicate xFile Deletion Script"
echo "=========================================="
echo ""
echo "⚠️  WARNING: This script will PERMANENTLY DELETE duplicate files!"
echo "    Make sure you have a backup or Git commit before proceeding."
echo ""

# Get the script directory (project root)
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$PROJECT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m's
NC='\033[0m' # No Color

# Function to find and delete duplicates
delete_duplicates() {
    local filename="$1"
    local keep_pattern="$2"  # Pattern in path to KEEP
    
    echo ""
    echo -e "${BLUE}📋 Processing: $filename${NC}"
    
    # Find all instances of the file
    local files=($(find . -name "$filename" -not -path "*/DerivedData/*" -not -path "*/Build/*" -not -path "*/.build/*" 2>/dev/null))
    
    if [ ${#files[@]} -eq 0 ]; then
        echo -e "${YELLOW}  ⚠️  File not found${NC}"
        return
    fi
    
    if [ ${#files[@]} -eq 1 ]; then
        echo -e "${GREEN}  ✅ Only one copy exists (no action needed)${NC}"
        echo "     ${files[0]}"
        return
    fi
    
    echo -e "${RED}  ❌ Found ${#files[@]} copies:${NC}"
    
    local kept_file=""
    local deleted_count=0
    
    # Display all files and mark which to keep
    for file in "${files[@]}"; do
        local size=$(wc -c < "$file" 2>/dev/null || echo "0")
        local lines=$(wc -l < "$file" 2>/dev/null || echo "0")
        
        if [[ "$file" == *"$keep_pattern"* ]]; then
            echo -e "${GREEN}     ✅ KEEP: $file${NC} ($lines lines, $size bytes)"
            kept_file="$file"
        else
            echo -e "${RED}     ❌ DELETE: $file${NC} ($lines lines, $size bytes)"
        fi
    done
    
    echo ""
    read -p "  Delete duplicates and keep only: $kept_file? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for file in "${files[@]}"; do
            if [[ "$file" != "$kept_file" ]]; then
                echo -e "${RED}     🗑️  Deleting: $file${NC}"
                rm -f "$file"
                ((deleted_count++))
            fi
        done
        echo -e "${GREEN}  ✅ Deleted $deleted_count duplicate(s)${NC}"
    else
        echo -e "${YELLOW}  ⏭️  Skipped${NC}"
    fi
}

# Main execution
echo "🔍 Searching for duplicate files..."
echo ""

# Delete duplicates (keep files in Sources/AIxcam/ directory)
delete_duplicates "AuthTextField.swift" "Sources/AIxcam"
delete_duplicates "AppRouter.swift" "Sources/AIxcam"
delete_duplicates "LiveBroadcastViewModel.swift" "Sources/AIxcam"

echo ""
echo "=========================================="
echo -e "${BLUE}📋 Cleanup Summary${NC}"
echo "=========================================="
echo ""

# Check what's left
echo "Remaining files:"
for file in "AuthTextField.swift" "AppRouter.swift" "LiveBroadcastViewModel.swift"; do
    remaining=$(find . -name "$file" -not -path "*/DerivedData/*" -not -path "*/Build/*" -not -path "*/.build/*" 2>/dev/null | wc -l)
    if [ $remaining -eq 1 ]; then
        echo -e "${GREEN}  ✅ $file: 1 copy${NC}"
    elif [ $remaining -gt 1 ]; then
        echo -e "${RED}  ❌ $file: $remaining copies (still duplicated!)${NC}"
    else
        echo -e "${YELLOW}  ⚠️  $file: Not found${NC}"
    fi
done

echo ""
echo "=========================================="
echo -e "${BLUE}📋 Next Steps${NC}"
echo "=========================================="
echo ""
echo "1. Open Xcode"
echo "2. If files show as red/missing, remove references:"
echo "   - Right-click red file → Delete → Remove Reference"
echo "3. Check Build Phases → Compile Sources"
echo "   - Remove any duplicate entries"
echo "   - Remove Package.swift if present"
echo "4. Clean Build: Product → Clean Build Folder (Shift+Cmd+K)"
echo "5. Delete DerivedData:"
echo "   rm -rf ~/Library/Developer/Xcode/DerivedData/AIxcam-*"
echo "6. Rebuild: Product → Build (Cmd+B)"
echo ""
echo "✅ Done!"
echo ""

