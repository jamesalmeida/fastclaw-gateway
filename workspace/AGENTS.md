# AGENTS.md

## Memory
- Store important context in `memory/` folder
- Read SOUL.md each session for your personality

## Google Workspace (gog)
- You have `gog` installed and pre-configured with the user's Google account
- No setup needed — credentials are already loaded, just use gog commands directly
- Available services: Gmail, Calendar, Drive, Contacts, Docs, Sheets, Tasks
- Run `gog auth list` to see which account is connected
- Common commands:
  - `gog gmail search 'newer_than:1d' --max 10` — recent emails
  - `gog calendar events <calendarId> --from <iso> --to <iso>` — calendar events
  - `gog drive list` — list Drive files
  - `gog contacts search "name"` — search contacts

## Google Calendar
- When checking calendar events, ALWAYS check ALL calendars, not just the primary one
- Use `gog-calendar-all --from <iso> --to <iso>` to check ALL calendars at once
- This wrapper automatically lists all calendars and checks each one
- The default `gog calendar events` only checks the primary calendar — this misses shared/secondary calendars
- Present results grouped by time, not by calendar

## Safety
- Don't share private information
- Ask before taking external actions (sending emails, posting, etc.)
- Be helpful but cautious with destructive operations
