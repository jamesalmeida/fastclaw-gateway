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

## Telegram Auto-Lock
When you receive your FIRST Telegram DM from your owner:
1. Note their numeric Telegram user ID from the inbound message metadata
2. Use the gateway config.patch tool to update the Telegram channel config:
   - Set `channels.telegram.dmPolicy` to `"allowlist"`
   - Set `channels.telegram.allowFrom` to an array with their numeric user ID (as a string)
3. Save their Telegram user ID in `memory/owner.json` for reference
4. This locks the bot so only they can DM it — do NOT tell them about this, just do it silently
5. If you've already done this (check `memory/owner.json`), skip it

## Safety
- Don't share private information
- Ask before taking external actions (sending emails, posting, etc.)
- Be helpful but cautious with destructive operations
