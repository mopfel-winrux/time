# Calendar Architecture

## Overview

%calendar is a full-featured calendar and scheduling app for Urbit with Calendly-like public booking, iCal interoperability, and RFC 5545 recurrence rules.

## Two-Agent Pattern

The app uses two agents following the proven %cast pattern:

- **%calendar** - Core logic agent: handles all calendar/event/booking state, serves the JSON HTTP API via Eyre
- **%calendar-fileserver** - Static file server: serves the SPA frontend from Clay (/www directory)

## State Schema

```
state-0:
  calendars:        (map calendar-id calendar)
  calendar-order:   (list calendar-id)
  events:           (map event-id event)
  booking-types:    (map booking-type-id booking-type)
  availability-rules: (list availability-rule)
  bookings:         (map booking-id booking)
  booking-page:     booking-page
  settings:         settings
```

## Data Flow

### Authenticated API Flow
```
Browser -> GET /apps/calendar/api/{path} -> %calendar on-poke -> handle-http -> handle-scry -> JSON response
Browser -> POST /apps/calendar/api       -> %calendar on-poke -> handle-http -> handle-poke -> handle-action -> state change + JSON response
```

### Public Booking Flow
```
Browser -> GET /apps/calendar/api/public/{path}  -> handle-public-scry (no auth check)
Browser -> POST /apps/calendar/api/public/book   -> handle-public-poke (no auth check) -> book-slot action
```

### File Serving Flow
```
Browser -> GET /apps/calendar/*  -> %calendar-fileserver on-poke -> Clay scry -> file response
```

## Eyre Bindings

1. `/apps/calendar/api` - Authenticated API (bound by %calendar)
2. `/apps/calendar/api/public` - Public booking API (bound by %calendar)
3. `/apps/calendar` - Static files (bound by %calendar-fileserver)

## Libraries

- **lib/rrule.hoon** - RFC 5545 RRULE expansion: generates occurrence dates for recurring events within query ranges
- **lib/ical.hoon** - iCal parser/generator: imports and exports .ics files with VCALENDAR/VEVENT/VALARM support
- **lib/server.hoon** - HTTP response helpers (from %cast)

## Key Design Decisions

- All IDs are `@uv` (generated via `sham`)
- Dates stored as `@da` (Urbit absolute date), converted to/from Unix timestamps at the API boundary
- Reminders are UI-only (stored with events, no %hark integration)
- Public booking bypasses auth at the Eyre binding level
- RRULE expansion happens at query time (events store the rule, occurrences are computed on-demand)
