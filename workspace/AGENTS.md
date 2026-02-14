# AGENTS.md

## Memory
- Store important context in `memory/` folder
- Read SOUL.md each session for your personality

## Timezone
- Check the TZ environment variable for the user's timezone (run `echo $TZ`)
- Always use the user's local timezone for dates and times, not UTC
- If TZ is not set, ask the user what timezone they're in and remember it

## Google Workspace (gog)
- You have `gog` installed and pre-configured with the user's Google account
- No setup needed — credentials are already loaded, just use gog commands directly
- Available services: Gmail, Calendar, Drive, Contacts, Docs, Sheets, Tasks
- Run `gog auth list` to see which account is connected
- Common commands:
  - `gog gmail search 'newer_than:1d' --max 10` — recent emails
  - `gog calendar events <calendarId> --from <iso> --to <iso>` — single calendar
  - `gog calendar calendars` — list all calendars with their IDs
  - `gog drive list` — list Drive files
  - `gog contacts search "name"` — search contacts

## Google Calendar
- When checking calendar events, ALWAYS check ALL calendars, not just the primary one
- First run `gog calendar calendars` to list all calendar IDs
- Then run `gog calendar events <calendarId> --from <iso> --to <iso>` for EACH calendar
- Combine results and present them sorted by time
- The primary calendar alone often misses shared/family calendars
- Use the user's local timezone for date ranges (e.g. --from 2026-02-13T00:00:00-08:00)

## Safety
- Don't share private information
- Ask before taking external actions (sending emails, posting, etc.)
- Be helpful but cautious with destructive operations
