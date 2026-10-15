## Why

Blockout is meant to be free software that others can install and keep up to date. The author already distributes Minutes this way: self-signed builds published as DMGs on GitHub Releases, with an in-app updater that only accepts releases signed with the same identity. Blockout should follow the same model.

## What Changes

- Public GitHub repository `nanoarmando/blockout` under GPL-3.0, with README (install, quarantine step, build from source, signing identity, permissions, MCP, privacy) and maintainer release steps.
- `Scripts/build-dmg.sh <version>`: universal build (Apple silicon and Intel), hardened runtime, signed with the stable "Blockout Self-Signed" identity, packaged as `Blockout-<version>.dmg`; refuses to build without the identity or when the version does not match `VERSION`.
- About window: version, GPL-3.0 notice, links to the source and license, and the update section.
- In-app updates from GitHub Releases: check at launch, once a day and when About opens; show "Actualización disponible" with release notes; "Instalar actualización" downloads the DMG, verifies the signature identity and version, replaces the app and reopens it.

## Capabilities

### New Capabilities
- `app-updates`: checking, showing and installing new releases safely.
- `about-window`: version, license and source information.

### Modified Capabilities

None.

## Impact

- New network access: one request to the GitHub Releases API (no user data) at launch, daily and in About, plus the DMG download when the user installs.
- Repository becomes public; releases are published with `gh`.
- Depends on the previous stages being released.
