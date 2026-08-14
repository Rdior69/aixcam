# Contributing to AIxcam

## Git Workflow

This document outlines the Git workflow for maintaining consistency across the AIxcam project.

## Before Making Changes

### 1. Ensure Your Branch is Up to Date

Always pull the latest changes before starting work:

```bash
# Fetch latest changes from GitHub
git fetch origin

# Pull changes into your current branch
git pull origin main
```

### 2. Check Current Status

```bash
# See what files have changed
git status

# See what changes you've made
git diff
```

## Making Changes

### 1. Create a Feature Branch (Recommended)

```bash
# Create and switch to a new branch
git checkout -b feature/your-feature-name

# Or for bug fixes
git checkout -b fix/bug-description
```

### 2. Make Your Changes

- Edit files as needed
- Run scripts like `fix_duplicates.sh` or `DELETE_DUPLICATES.sh`
- Test your changes

### 3. Stage Your Changes

```bash
# Add specific files
git add filename.swift

# Add all changed files
git add .

# Add documentation files
git add *.md *.sh
```

### 4. Commit Your Changes

Write clear, descriptive commit messages:

```bash
# Commit with a message
git commit -m "Fix: Remove duplicate Swift files causing build errors"

# Or for documentation changes
git commit -m "Docs: Update build setup instructions"
```

#### Commit Message Convention

Use these prefixes for clarity:
- `Fix:` - Bug fixes
- `Feat:` - New features
- `Docs:` - Documentation changes
- `Refactor:` - Code refactoring
- `Test:` - Adding or updating tests
- `Chore:` - Maintenance tasks
- `Build:` - Build system changes

### 5. Push Your Changes

```bash
# Push to your branch
git push origin feature/your-feature-name

# Or if you're working directly on main (not recommended for teams)
git push origin main
```

## Syncing with GitHub

### Pull Latest Changes

```bash
# Pull from main branch
git pull origin main

# If you have conflicts, resolve them and then:
git add .
git commit -m "Merge: Resolve conflicts with main"
```

### Merge Feature Branch to Main

```bash
# Switch to main branch
git checkout main

# Pull latest changes
git pull origin main

# Merge your feature branch
git merge feature/your-feature-name

# Push to GitHub
git push origin main

# Delete the feature branch (optional)
git branch -d feature/your-feature-name
```

## Documentation Consistency

### Files to Keep Updated

1. **README.md** - Project overview, setup instructions
2. **CONTRIBUTING.md** - This file
3. **Scripts** - Keep comments and usage instructions current
4. **Code Comments** - Update inline documentation

### Before Committing Documentation

1. Check for typos and formatting
2. Ensure code examples are current
3. Update version numbers if applicable
4. Test any scripts or commands mentioned

## Common Scenarios

### After Running Duplicate Deletion Scripts

```bash
# Check what was deleted
git status

# Review changes
git diff

# Stage deleted files
git add -u

# Stage any new files
git add .

# Commit with descriptive message
git commit -m "Fix: Remove duplicate Swift files

- Removed duplicate AuthTextField.swift
- Removed duplicate AppRouter.swift  
- Removed duplicate LiveBroadcastViewModel.swift
- Updated build configuration"

# Push to GitHub
git push origin main
```

### Updating Documentation Only

```bash
# Stage documentation files
git add README.md CONTRIBUTING.md *.md

# Commit
git commit -m "Docs: Update build setup and contribution guidelines"

# Push
git push origin main
```

### Rolling Back Changes

```bash
# Undo last commit (keep changes)
git reset --soft HEAD~1

# Undo last commit (discard changes)
git reset --hard HEAD~1

# Restore a specific file
git checkout -- filename.swift
```

## Best Practices

1. **Commit Often** - Small, focused commits are better than large ones
2. **Write Clear Messages** - Future you will thank present you
3. **Pull Before Push** - Always sync before pushing
4. **Test Before Commit** - Ensure your changes work
5. **Document Changes** - Update relevant documentation
6. **Use Branches** - Keep main stable, experiment in branches
7. **Review Before Push** - Use `git diff` and `git status`

## Conflict Resolution

If you encounter merge conflicts:

```bash
# See which files have conflicts
git status

# Open conflicted files and look for:
# <<<<<<< HEAD
# Your changes
# =======
# Their changes
# >>>>>>> branch-name

# Edit files to resolve conflicts
# Then stage the resolved files
git add resolved-file.swift

# Complete the merge
git commit -m "Merge: Resolve conflicts"
```

## Getting Help

```bash
# See commit history
git log

# See changes in a commit
git show commit-hash

# See all branches
git branch -a

# See remote repositories
git remote -v
```

## Automation

Consider setting up Git hooks for automation:

### Pre-commit Hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
# Run Swift format check
# Run tests
# Check for sensitive data
```

### Pre-push Hook

Create `.git/hooks/pre-push`:

```bash
#!/bin/bash
# Run full test suite
# Check build succeeds
```

## Questions?

If you're unsure about a Git operation:
1. Check `git status` to see current state
2. Use `git diff` to review changes
3. Make a backup branch before complex operations
4. Consult the team before force pushing

---

**Remember:** Communication and consistency are key to good collaboration!
