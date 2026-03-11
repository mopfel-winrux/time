# iCal Import/Export

## Overview

The calendar app supports full iCal (.ics) interoperability for importing and exporting calendar data per RFC 5545.

## Import

### Via UI
1. Navigate to `#/import`
2. Enter a calendar name
3. Select a .ics file
4. Click Import

### Via API
```json
POST /apps/calendar/api
{
  "action": "import-ical",
  "cal-name": "My Calendar",
  "ics-data": "BEGIN:VCALENDAR\r\n..."
}
```

### Supported Properties (Import)
- `SUMMARY` -> event title
- `DESCRIPTION` -> event description
- `DTSTART` / `DTEND` -> start/end times (date-time and date-only)
- `LOCATION` -> event location
- `RRULE` -> recurrence rules (see below)
- `UID` -> preserved for deduplication
- `VALARM` with `TRIGGER` -> reminder (minutes before)
- `X-WR-CALNAME` -> calendar name
- `X-WR-CALDESC` -> calendar description

### Line Unfolding
The parser handles RFC 5545 line continuations (lines starting with space/tab are appended to the previous line).

## Export

### Via UI
Navigate to `#/calendars` and click "Export .ics" on any calendar.

### Via API
```
GET /apps/calendar/api/export-ical/{calendar-id}  -> single calendar
GET /apps/calendar/api/export-ical                 -> all calendars
```

Returns a `text/calendar` response with `Content-Disposition: attachment`.

### Generated Properties (Export)
- `VCALENDAR` with `VERSION`, `PRODID`, `X-WR-CALNAME`
- `VEVENT` with `UID`, `SUMMARY`, `DESCRIPTION`, `DTSTART`, `DTEND`, `LOCATION`, `RRULE`
- `VALARM` with `TRIGGER` for reminders

## RRULE Coverage

### Supported Frequencies
- `DAILY` - every N days
- `WEEKLY` - every N weeks
- `MONTHLY` - every N months
- `YEARLY` - every N years

### Supported RRULE Parts
| Part | Example | Description |
|------|---------|-------------|
| `FREQ` | `FREQ=WEEKLY` | Recurrence frequency |
| `INTERVAL` | `INTERVAL=2` | Every 2nd occurrence |
| `UNTIL` | `UNTIL=20241231T235959Z` | End date |
| `COUNT` | `COUNT=10` | Max 10 occurrences |
| `BYDAY` | `BYDAY=MO,WE,FR` | By day of week |
| `BYMONTHDAY` | `BYMONTHDAY=1,15` | By day of month |
| `BYMONTH` | `BYMONTH=1,6` | By month |
| `BYSETPOS` | `BYSETPOS=-1` | Position in set |
| `WKST` | `WKST=MO` | Week start day |
| `EXDATE` | Stored in rule | Excluded dates |

### Expansion
RRULE expansion happens at query time via `lib/rrule.hoon`. When events are fetched for a date range, recurring events are expanded into individual occurrences within that range. Each occurrence inherits the parent event's properties with adjusted start/end times.
