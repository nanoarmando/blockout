## Purpose

Keeps installed copies of Blockout up to date from its public GitHub releases while refusing any build not signed by the same identity.

## ADDED Requirements

### Requirement: Check for updates
Blockout SHALL check the latest GitHub release of the project at launch, once a day while running and whenever About opens. The request SHALL carry no user data. When the latest version is newer than the installed one, the main menu and the menu bar menu SHALL show "Actualización disponible". Network errors SHALL be silent outside About.

#### Scenario: New version published
- **WHEN** version 1.1.0 is published and 1.0.0 is installed
- **THEN** "Actualización disponible" appears and About shows the 1.1.0 release notes

#### Scenario: Offline
- **WHEN** the check fails for lack of network
- **THEN** nothing is shown outside About, and About says the check could not be completed

### Requirement: Install an update
"Instalar actualización" in About SHALL download the release DMG, verify that the app inside is signed with the same identity as the running app and that its version matches the release, ask for confirmation, then replace the installed app and reopen it. Any failed check SHALL abort without changing the installed app and SHALL explain the reason. Installing SHALL be disabled while a timer is running.

#### Scenario: Different signature
- **WHEN** the downloaded app is signed with another identity
- **THEN** the update is refused with the reason and the installed app is unchanged

#### Scenario: Timer running
- **WHEN** a timer is running
- **THEN** "Instalar actualización" is disabled with the hint to stop the timer first

### Requirement: Permissions survive updates
Updates signed with the same identity SHALL keep the Calendar and notification permissions and all data and settings.

#### Scenario: After updating
- **WHEN** Blockout reopens after an update
- **THEN** tasks, blocks, settings and permissions are as before
