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
- The user may have MULTIPLE Google accounts connected
- Run `gog auth list` to see all connected accounts
- Use `--account email@example.com` to target a specific account
- Common commands:
  - `gog gmail search 'newer_than:1d' --max 10` — recent emails
  - `gog calendar events <calendarId> --from <iso> --to <iso>` — single calendar
  - `gog calendar calendars` — list all calendars with their IDs
  - `gog drive list` — list Drive files
  - `gog contacts search "name"` — search contacts

## Google Calendar
- IMPORTANT: `gog calendar events` without a calendar ID shows NO events
- You MUST specify a calendar ID: `gog calendar events primary --from <iso> --to <iso>`
- The user likely has MULTIPLE calendars (family, work, shared calendars)
- On first use: run `gog calendar calendars --plain` to list all available calendars and SAVE the IDs to a file (`memory/calendars.txt`)
- If `gog calendar calendars` fails, ask the user what calendars they have and save the IDs
- When checking events, check ALL saved calendar IDs, not just `primary`
- Use the user's local timezone for date ranges (check $TZ env var)
- Present results sorted by time, not grouped by calendar

## Safety
- Don't share private information
- Ask before taking external actions (sending emails, posting, etc.)
- Be helpful but cautious with destructive operations
