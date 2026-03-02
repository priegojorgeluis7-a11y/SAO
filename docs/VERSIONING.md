# Versioning Guide

This repository uses:
- `VERSION` for the current app version (SemVer)
- `CHANGELOG.md` for release notes
- Git tags `vX.Y.Z` for immutable snapshots

## Release checklist
1. Update `VERSION` (e.g. `0.1.1`).
2. Add entry in `CHANGELOG.md`.
3. Commit changes.
4. Create tag: `git tag v0.1.1`.

## Useful commands
- Current version: `Get-Content VERSION`
- Create release commit:
  - `git add VERSION CHANGELOG.md`
  - `git commit -m "release: v0.1.1"`
- Create tag:
  - `git tag v0.1.1`
- Show tags:
  - `git tag --list`
