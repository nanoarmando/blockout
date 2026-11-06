## Context

See proposal.md - Why. `StartPrompts` schedules start and end notifications for today's blocks with calendar triggers, handles their actions, tracks snooze/skip state in memory, reads authorization, and powers the menu bar warning and prompt fallback. It is created at startup and injected into the menu bar view. No other code uses notifications.

## Goals / Non-Goals

**Goals:** no block notifications, no permission request, no leftover scheduled prompts after updating.

**Non-Goals:** a setting to turn prompts back on, other notification types, changing the timer or the menu actions.

## Decisions

- **Delete `StartPrompts` instead of disabling it.** A toggle would keep unused code (YAGNI). Alternative: a setting; rejected because the user wants them gone.
- **One-time-safe cleanup at launch.** Startup calls `removeAllPendingNotificationRequests()` and `removeAllDeliveredNotifications()` on the notification center. It does not request authorization, so it never shows a permission dialog; it is harmless on every launch and keeps working for users updating from any earlier version.
- **Menu bar view loses the warning and the prompt fallback**; its timer controls stay.

## Risks / Trade-offs

- [A user relied on the prompt to start the timer] → the timer can still be started from the task detail ("Retomar cronómetro") and the menu bar.
- [macOS keeps Blockout in the notification settings list] → harmless; it simply never posts.

## Migration Plan

No data changes. Ships in the next Blockout release; rollback by installing the previous release.
