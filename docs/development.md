# Development Guide

## Prerequisites

- Urbit runtime (binary at project root)
- Fake ship (zod) running
- MCP tools configured

## Build & Deploy

### Initial Setup
```
# Create the desk on the ship
mcp__zod__new-desk desk=calendar

# Copy files
mcp__zod__commit-desk desk=calendar

# Install the app
mcp__zod__install-app desk=calendar
```

### Development Cycle
1. Edit files in `desk/`
2. Commit to ship: `mcp__zod__commit-desk desk=calendar`
3. Changes auto-reload (Clay watches for updates)

### File Structure
- `desk/app/` - Gall agents
- `desk/sur/` - Type definitions
- `desk/lib/` - Libraries
- `desk/mar/` - Marks (data type converters)
- `desk/www/` - Frontend static files
- `desk/tests/` - Unit tests

## Testing

### Run all tests
```
mcp__zod__run-tests desk=calendar path=/tests
```

### Test specific library
```
mcp__zod__run-tests desk=calendar path=/tests/lib/rrule
```

## Verification

1. **Scry test**: `mcp__zod__scry path=/gx/calendar/calendars/json` should return `{"calendars":[]}`
2. **Frontend**: Browse to `http://localhost:8080/apps/calendar` - should load the SPA
3. **Create calendar**: POST create-calendar action, verify with GET /calendars
4. **Booking flow**: Set availability -> create booking type -> enable booking page -> visit public URL -> book a slot
5. **iCal export**: GET /api/export-ical/:id -> valid .ics file
6. **iCal import**: POST import-ical with .ics content -> events appear

## Architecture Notes

- The agent uses inline JSON parsing (calendar-action-mark core within on-poke) instead of the separate mar/calendar-action.hoon mark for HTTP POST handling. The mark file exists for when actions come via Gall pokes from other agents.
- Public endpoints bypass auth by checking the URL path prefix before the authentication gate.
- RRULE expansion is lazy - computed at query time, not stored.
