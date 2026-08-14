# Git Commit Message Templates

Use these templates when committing changes to maintain consistency.

## Format

```
Type: Brief description (50 chars or less)

Detailed explanation if needed (wrap at 72 characters)

- Bullet points for specific changes
- What was changed
- Why it was changed
```

## Types

- **Fix:** Bug fixes
- **Feat:** New features
- **Docs:** Documentation changes
- **Refactor:** Code refactoring (no functional changes)
- **Test:** Adding or updating tests
- **Chore:** Maintenance tasks
- **Build:** Build system or dependency changes
- **Perf:** Performance improvements
- **Style:** Code style/formatting changes

## Examples

### Bug Fix
```
Fix: Remove duplicate Swift files causing build errors

- Removed duplicate AuthTextField.swift from AIxcam/Modules/
- Removed duplicate AppRouter.swift
- Removed duplicate LiveBroadcastViewModel.swift
- Updated Xcode project file references
- Verified successful build after cleanup
```

### New Feature
```
Feat: Add live broadcast functionality

- Implemented LiveBroadcastViewModel
- Added broadcast UI components
- Integrated with streaming service
- Added error handling and retry logic
```

### Documentation
```
Docs: Add Git workflow and contribution guidelines

- Created CONTRIBUTING.md with complete Git workflow
- Added GIT_GUIDE.md for quick reference
- Added automated sync scripts
- Updated README with setup instructions
```

### Refactoring
```
Refactor: Simplify authentication flow

- Consolidated auth methods into AuthManager
- Removed redundant validation logic
- Improved error messages
- No functional changes
```

### Build/Configuration
```
Build: Update Swift Package Manager dependencies

- Updated Alamofire to 5.8.0
- Added SwiftLint configuration
- Fixed deprecated API warnings
```

### Chore
```
Chore: Clean up project structure

- Removed unused files
- Organized source directories
- Updated .gitignore
- Cleaned up Xcode project settings
```

### Multiple Changes
```
Fix: Resolve build and documentation issues

Build fixes:
- Removed duplicate Swift files
- Fixed missing framework references
- Updated deployment target to iOS 16

Documentation:
- Updated README setup instructions
- Added Git workflow guide
- Created commit message templates
```

## Quick Reference

### After Duplicate Cleanup
```bash
git commit -m "Fix: Remove duplicate Swift files

- Removed duplicate AuthTextField.swift
- Removed duplicate AppRouter.swift
- Removed duplicate LiveBroadcastViewModel.swift"
```

### After Documentation Update
```bash
git commit -m "Docs: Update build and contribution guides"
```

### After Adding Feature
```bash
git commit -m "Feat: Add user authentication

- Implemented login/logout flow
- Added token management
- Integrated with backend API"
```

### After Code Cleanup
```bash
git commit -m "Refactor: Clean up view controller logic

- Extracted business logic to view models
- Simplified view hierarchy
- Improved code readability"
```

### After Test Addition
```bash
git commit -m "Test: Add unit tests for authentication

- Added AuthManager tests
- Added token validation tests
- Achieved 85% code coverage"
```

## Using Templates in Git

### Set up commit template (optional)

1. Create template file:
```bash
echo "Type: Brief description

Detailed explanation:

- 
- 
- 

# Types: Fix, Feat, Docs, Refactor, Test, Chore, Build, Perf, Style" > ~/.gitmessage
```

2. Configure Git to use it:
```bash
git config --global commit.template ~/.gitmessage
```

3. When you commit:
```bash
git commit  # Opens editor with template
```

## Tips

1. **First line (subject):**
   - Max 50 characters
   - Start with type prefix
   - Use imperative mood ("Add" not "Added")
   - Don't end with period

2. **Body (optional):**
   - Wrap at 72 characters
   - Explain what and why, not how
   - Use bullet points for clarity

3. **Reference issues:**
   ```
   Fix: Resolve authentication bug

   - Fixed token refresh logic
   - Added better error handling
   
   Fixes #123
   ```

4. **Breaking changes:**
   ```
   Feat: Update API to v2

   BREAKING CHANGE: API endpoint URLs have changed.
   Update base URL in configuration.
   ```

## Common Mistakes to Avoid

❌ **Bad:**
```
git commit -m "updates"
git commit -m "fixed stuff"
git commit -m "WIP"
```

✅ **Good:**
```
git commit -m "Fix: Resolve authentication timeout issue"
git commit -m "Refactor: Extract network logic to service layer"
git commit -m "Feat: Add dark mode support"
```

## Automated with Scripts

Use the provided scripts for consistent commits:

```bash
# Interactive with templates
./git_sync.sh

# Complete workflow
./complete_sync.sh
```

Both scripts provide suggested commit messages following this format!

---

**Remember:** Good commit messages help your future self and your teammates understand what changed and why.
