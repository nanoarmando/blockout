## 1. Build and signing

- [x] 1.1 Port `Scripts/build-dmg.sh` from Minutes: universal build, hardened runtime, "Blockout Self-Signed" identity, `VERSION` check, `Blockout-<version>.dmg` (D1)
- [x] 1.2 Document creating and backing up the signing identity in the README

## 2. App

- [x] 2.1 Build the About window with version, GPL-3.0 notice, source and license links (about-window)
- [x] 2.2 Implement the release check (launch, daily, About) and "Actualización disponible" in the app and menu bar menus (D3; app-updates)
- [x] 2.3 Implement download, signature and version verification, confirmation, swap with rollback and reopen; disabled while a timer runs (D2)

## 3. Publication

- [x] 3.1 Complete the README (install, quarantine step, build from source, permissions, MCP, privacy including the GitHub check) and AGENTS; add the "Releases (maintainers)" section
- [ ] 3.2 Create the public GitHub repository `nanoarmando/blockout` and push
- [ ] 3.3 Publish release `1.0.0` with `gh release create` and the DMG

## 4. Verification

- [ ] 4.1 Install the DMG on a clean user account following the README; update from 1.0.0 to a test 1.0.1; confirm a differently signed build is refused
