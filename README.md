# AIxcam Project

AI-powered camera application for iOS.

## 📱 Overview

AIxcam is a Swift-based iOS application that combines camera functionality with AI capabilities.

## 🚀 Quick Start

### Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- iOS 16.0+ deployment target
- Swift 5.9+

### Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/AIxcam.git
   cd AIxcam
   ```

2. **Open in Xcode:**
   ```bash
   open AIxcam.xcodeproj
   # or
   xed .
   ```

3. **Build and run:**
   - Select your target device/simulator
   - Press `Cmd+R` to build and run

### First Time Setup

If you encounter build errors due to duplicate files:

```bash
# Make scripts executable
chmod +x fix_duplicates.sh
chmod +x DELETE_DUPLICATES.sh
chmod +x complete_sync.sh
chmod +x git_sync.sh

# Check for duplicates
./fix_duplicates.sh

# Remove duplicates (interactive)
./DELETE_DUPLICATES.sh

# Clean Xcode
# In Xcode: Product → Clean Build Folder (Shift+Cmd+K)
rm -rf ~/Library/Developer/Xcode/DerivedData/AIxcam-*

# Build again
# In Xcode: Product → Build (Cmd+B)
```

## 📚 Documentation

### Getting Started
- **[SETUP_COMPLETE.md](SETUP_COMPLETE.md)** - Quick start guide
- **[GIT_GUIDE.md](GIT_GUIDE.md)** - Git quick reference
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Complete contribution guide
- **[COMMIT_TEMPLATES.md](COMMIT_TEMPLATES.md)** - Commit message examples

### Scripts
- `fix_duplicates.sh` - Find duplicate files (non-destructive)
- `DELETE_DUPLICATES.sh` - Remove duplicates interactively
- `git_sync.sh` - Interactive Git workflow tool
- `complete_sync.sh` - All-in-one cleanup and sync

## 🛠️ Development Workflow

### Daily Workflow

```bash
# 1. Start your day
git pull origin main

# 2. Make your changes
# ... code ...

# 3. End of day (automated)
./complete_sync.sh

# Or manual:
git add .
git commit -m "Type: Description of changes"
git push origin main
```

### Feature Development

```bash
# Create feature branch
git checkout -b feature/your-feature

# Make changes and commit
git add .
git commit -m "Feat: Add your feature"

# Push to GitHub
git push origin feature/your-feature

# Merge when ready
git checkout main
git merge feature/your-feature
git push origin main
```

### Using Automated Scripts

**For complete workflow:**
```bash
./complete_sync.sh
```
Guides you through: duplicate check → Xcode cleanup → commit → push

**For Git operations only:**
```bash
./git_sync.sh
```
Interactive menu for: commit, pull, push, branch management

## 📁 Project Structure

```
AIxcam/
├── Sources/
│   └── AIxcam/              # Main application code
│       ├── Views/           # SwiftUI views
│       ├── ViewModels/      # View models
│       ├── Models/          # Data models
│       ├── Services/        # Business logic
│       └── Utils/           # Utilities
├── Tests/                   # Unit and UI tests
├── Documentation/           # Additional docs
├── Scripts/                 # Build and utility scripts
└── Resources/              # Assets and resources
```

## 🔧 Common Tasks

### Clean Build

```bash
# In Xcode
# Product → Clean Build Folder (Shift+Cmd+K)

# Command line
rm -rf ~/Library/Developer/Xcode/DerivedData/AIxcam-*
```

### Fix Duplicate Files

```bash
# Find duplicates
./fix_duplicates.sh

# Remove duplicates
./DELETE_DUPLICATES.sh
```

### Update Dependencies

```bash
# Swift Package Manager
# In Xcode: File → Packages → Update to Latest Package Versions

# Or reset package cache
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf .build
```

### Run Tests

```bash
# In Xcode
# Product → Test (Cmd+U)

# Command line (if using SPM)
swift test
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md).

### Quick Contribution Steps

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Commit using our format (`git commit -m "Feat: Add amazing feature"`)
5. Push to your branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

### Commit Message Format

We use conventional commits:

```
Type: Brief description

- Detailed changes
- What was added/fixed
- Why it was needed
```

**Types:** `Fix`, `Feat`, `Docs`, `Refactor`, `Test`, `Chore`, `Build`

See [COMMIT_TEMPLATES.md](COMMIT_TEMPLATES.md) for examples.

## 🐛 Troubleshooting

### Build Errors

**"Duplicate symbol" errors:**
```bash
./DELETE_DUPLICATES.sh  # Remove duplicate files
# Then clean and rebuild in Xcode
```

**"No such module" errors:**
```bash
# Clean and rebuild
rm -rf ~/Library/Developer/Xcode/DerivedData/AIxcam-*
# Product → Clean Build Folder
# Product → Build
```

**Swift Package Manager issues:**
```bash
# Reset package cache
rm -rf .build
rm -rf ~/Library/Caches/org.swift.swiftpm
# In Xcode: File → Packages → Reset Package Cache
```

### Git Issues

**Push rejected:**
```bash
git pull origin main  # Pull latest changes
# Resolve any conflicts
git push origin main
```

**Merge conflicts:**
```bash
git status           # See conflicted files
# Edit files to resolve conflicts
git add .
git commit -m "Merge: Resolve conflicts"
```

See [GIT_GUIDE.md](GIT_GUIDE.md) for more Git help.

## 📋 Requirements

### Development
- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

### Target Platforms
- iOS 16.0+
- iPadOS 16.0+

### Dependencies
See `Package.swift` for current dependencies.

## 📄 License

[Add your license here]

## 👥 Team

[Add team information here]

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/yourusername/AIxcam/issues)
- **Discussions:** [GitHub Discussions](https://github.com/yourusername/AIxcam/discussions)
- **Documentation:** See docs in this repository

## 🗺️ Roadmap

[Add roadmap items here]

- [ ] Feature 1
- [ ] Feature 2
- [ ] Feature 3

## 📊 Status

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![Swift Version](https://img.shields.io/badge/Swift-5.9-orange)
![Platform](https://img.shields.io/badge/platform-iOS%2016+-blue)

## 🔗 Links

- **Documentation:** [SETUP_COMPLETE.md](SETUP_COMPLETE.md)
- **Contributing:** [CONTRIBUTING.md](CONTRIBUTING.md)
- **Git Guide:** [GIT_GUIDE.md](GIT_GUIDE.md)
- **Commit Templates:** [COMMIT_TEMPLATES.md](COMMIT_TEMPLATES.md)

---

**Made with ❤️ by the AIxcam team**

Last updated: August 11, 2026
