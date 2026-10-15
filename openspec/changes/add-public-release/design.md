## Context

See proposal.md. The author's Minutes app already implements this distribution model: `Scripts/build-dmg.sh`, a "Minutes Self-Signed" identity created with `openssl` and imported into the login keychain, GitHub Releases with `gh`, quarantine instructions in the README, and an updater that verifies the signing identity. Blockout reuses that approach.

## Goals / Non-Goals

**Goals:** free distribution without an Apple Developer account; safe self-updates.

**Non-Goals:** notarization, Mac App Store, Homebrew cask, automatic background installs.

## Decisions

### D1. Same model and scripts as Minutes
Port Minutes' `build-dmg.sh`, signing instructions and updater logic, renamed for Blockout. Alternative: notarized builds — needs a paid Apple Developer account; rejected by the user's choice to follow Minutes.

### D2. Updater verifies the designated requirement
The downloaded app's code signature must satisfy the running app's designated requirement (same leaf certificate) and its `CFBundleShortVersionString` must equal the release tag. Unzip/mount into a temporary folder, swap with a detached helper script with rollback, like the author's other apps.

### D3. Unauthenticated GitHub API
The repository is public, so the updater calls `https://api.github.com/repos/nanoarmando/blockout/releases/latest` without tokens; rate limits are irrelevant at a few calls per day.

## Risks / Trade-offs

- [First launch shows Gatekeeper warnings] → README documents the one-time `xattr -dr com.apple.quarantine` step.
- [Losing the signing identity breaks updates for existing users] → README tells maintainers to back up the `.p12`; a new identity requires a manual reinstall.

## Migration Plan

Publish the repository, then release `1.0.0` built with `build-dmg.sh`. The author's own install switches from `build.sh --install` to the released DMG.
