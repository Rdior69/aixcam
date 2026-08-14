# AIxcam Git Quick Reference

Quick commands to keep your repository in sync with GitHub.

## 🚀 Quick Start

### Before You Start Working

```bash
# Pull latest changes
git pull origin main
```

### After Making Changes

```bash
# See what changed
git status

# Add all changes
git add .

# Commit with a message
git commit -m "Your descriptive message"

# Push to GitHub
git push origin main
```

## 📋 Common Workflows

### After Running Duplicate Cleanup Scripts

```bash
# 1. Review what was deleted/changed
git status
git diff

# 2. Stage all changes
git add .

# 3. Commit with descriptive message
git commit -m "Fix: Remove duplicate Swift files

- Removed duplicate AuthTextField.swift
- Removed duplicate AppRouter.swift
- Updated build configuration"

# 4. Sync with GitHub
git pull origin main
git push origin main
```

### Update Documentation Only

```bash
# Stage documentation files
git add *.md *.sh CONTRIBUTING.md

# Commit
git commit -m "Docs: Update build and contribution guides"

# Push
git push origin main
```

### Use the Automated Script

```bash
# Make script executable (first time only)
chmod +x git_sync.sh

# Run the sync tool
./git_sync.sh
```

## 🔧 Available Scripts

### `git_sync.sh`
Interactive Git workflow automation
- Quick commit and push
- Pull latest changes
- Full sync (pull + commit + push)
- Create feature branches
- View status and logs
- Sync documentation only

**Usage:**
```bash
chmod +x git_sync.sh
./git_sync.sh
```

### `fix_duplicates.sh`
Find duplicate Swift files (non-destructive)
- Lists all duplicate files
- Shows file locations
- Provides cleanup instructions

**Usage:**
```bash
chmod +x fix_duplicates.sh
./fix_duplicates.sh
```

### `DELETE_DUPLICATES.sh`
Automatically delete duplicate files (destructive)
- Prompts before deletion
- Shows file details
- Removes duplicates while keeping preferred copies

**Usage:**
```bash
chmod +x DELETE_DUPLICATES.sh
./DELETE_DUPLICATES.sh
```

## 📝 Commit Message Conventions

Use clear prefixes to categorize commits:

- `Fix:` - Bug fixes
- `Feat:` - New features
- `Docs:` - Documentation changes
- `Refactor:` - Code restructuring
- `Test:` - Test additions/updates
- `Chore:` - Maintenance tasks
- `Build:` - Build system changes

**Examples:**
```bash
git commit -m "Fix: Resolve duplicate file build errors"
git commit -m "Feat: Add live broadcast functionality"
git commit -m "Docs: Update setup instructions"
git commit -m "Refactor: Simplify authentication flow"
```

## 🔄 Syncing Your Fork

If you've forked the repository:

```bash
# Add upstream remote (one time)
git remote add upstream https://github.com/original/repo.git

# Fetch upstream changes
git fetch upstream

# Merge upstream into your main
git checkout main
git merge upstream/main

# Push to your fork
git push origin main
```

## 🌿 Branch Management

### Create a Feature Branch

```bash
# Create and switch to new branch
git checkout -b feature/my-new-feature

# Make changes, then commit
git add .
git commit -m "Feat: Add new feature"

# Push branch to GitHub
git push origin feature/my-new-feature
```

### Merge Branch to Main

```bash
# Switch to main
git checkout main

# Pull latest
git pull origin main

# Merge your branch
git merge feature/my-new-feature

# Push to GitHub
git push origin main

# Delete local branch (optional)
git branch -d feature/my-new-feature
```

## 🆘 Common Issues

### Merge Conflicts

```bash
# See conflicted files
git status

# Edit files to resolve conflicts
# Look for <<<<<<< HEAD markers

# After resolving, stage the files
git add resolved-file.swift

# Complete the merge
git commit -m "Merge: Resolve conflicts"
```

### Undo Last Commit (Keep Changes)

```bash
git reset --soft HEAD~1
```

### Undo Last Commit (Discard Changes)

```bash
git reset --hard HEAD~1
```

### Restore a File

```bash
git checkout -- filename.swift
```

### Clean Untracked Files

```bash
# Preview what will be removed
git clean -n

# Remove untracked files
git clean -f

# Remove untracked files and directories
git clean -fd
```

## 🎯 Best Practices

1. **Commit often** - Small, focused commits
2. **Pull before push** - Always sync first
3. **Write clear messages** - Help future you
4. **Test before commit** - Ensure code works
5. **Review before push** - Use `git status` and `git diff`
6. **Keep documentation updated** - Update relevant docs with code changes
7. **Use branches for features** - Keep main stable

## 🔍 Useful Commands

```bash
# See commit history
git log

# See compact history
git log --oneline -10

# See what changed in a commit
git show commit-hash

# See all branches
git branch -a

# See changes in staged files
git diff --cached

# See changes in a specific file
git diff filename.swift

# See who changed what in a file
git blame filename.swift

# Search commit messages
git log --grep="search term"
```

## 📚 Full Documentation

For complete Git workflow documentation, see [CONTRIBUTING.md](CONTRIBUTING.md)

## ✅ Complete Workflow Example

Here's a complete workflow from start to finish:

```bash
# 1. Start with latest code
git pull origin main

# 2. Create a feature branch
git checkout -b fix/duplicate-files

# 3. Run cleanup script
./DELETE_DUPLICATES.sh

# 4. Review changes
git status
git diff

# 5. Clean Xcode
# In Xcode: Product → Clean Build Folder (Shift+Cmd+K)
rm -rf ~/Library/Developer/Xcode/DerivedData/AIxcam-*

# 6. Test build
# In Xcode: Product → Build (Cmd+B)

# 7. Stage changes
git add .

# 8. Commit
git commit -m "Fix: Remove duplicate Swift files

- Removed duplicate AuthTextField.swift from AIxcam/Modules/
- Removed duplicate AppRouter.swift  
- Removed duplicate LiveBroadcastViewModel.swift
- Cleaned build configuration
- Verified build succeeds"

# 9. Push branch to GitHub
git push origin fix/duplicate-files

# 10. Merge to main (or create Pull Request on GitHub)
git checkout main
git pull origin main
git merge fix/duplicate-files
git push origin main

# 11. Clean up branch
git branch -d fix/duplicate-files
```

---

**Need help?** Run `./git_sync.sh` for an interactive workflow!
