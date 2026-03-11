# %time

A calendar and scheduling app for Urbit with iCal interoperability, RFC 5545 recurrence rules, and Calendly-style public booking.

## Features

- **Multiple calendars** with custom colors and descriptions
- **Event management** with location, description, all-day support, and reminders
- **Recurring events** via full RFC 5545 RRULE (daily/weekly/monthly/yearly, intervals, BYDAY, BYMONTHDAY, BYMONTH, BYSETPOS, UNTIL, COUNT, EXDATE)
- **iCal import/export** — import .ics files, export any calendar as .ics
- **Calendar subscriptions** — subscribe to external .ics URLs with automatic periodic refresh
- **Public booking** — Calendly-like scheduling page with availability rules, conflict detection, and buffer times
- **Responsive SPA** — month/week/day/agenda views, dark theme, PWA-installable
- **JSON HTTP API** — authenticated and public endpoints served via Eyre

## Installation

```
|new-desk %time
|mount %time
```

Copy the contents of `desk/` into your mounted `%time` directory, then:

```
|commit %time
|install our %time
```

The app will be available at `/apps/time/` in your browser.

## Desk Structure

```
desk/
  app/
    time.hoon              Main agent
    time-fileserver.hoon   Static file server
    fileserver/config.hoon Fileserver config (web-root, file-root)
  sur/
    calendar.hoon          All type definitions
  lib/
    ical.hoon              iCal parser/generator
    rrule.hoon             RRULE expansion engine
  mar/
    calendar-action.hoon   JSON -> action mark
    calendar-update.hoon   Update -> JSON mark
    ics.hoon               .ics file mark
    ...                    Standard web marks (json, html, css, js, etc.)
  www/
    index.html             SPA entry point
    manifest.json          PWA manifest
    js/api.js              API client
    js/app.js              Main SPA (~1040 lines)
    js/booking.js          Public booking interface
    css/app.css            Styles (dark theme)
  tests/
    lib/ical.hoon          8 iCal parser tests
    lib/rrule.hoon         8 RRULE expansion tests
  desk.bill                Agents: %time, %time-fileserver
  desk.docket-0            App metadata
  sys.kelvin               [%zuse 409]
```

## HTTP API

All endpoints are served by the `%time` agent via Eyre.

### Authenticated (`/apps/time/api/...`)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/calendars` | List all calendars with event counts |
| GET | `/calendar/:id` | Get a single calendar |
| GET | `/events?start=<unix>&end=<unix>&cal=<id>` | Events in range (expands recurrences) |
| GET | `/event/:id` | Get a single event |
| GET | `/booking-types` | List all booking types |
| GET | `/availability` | Get availability rules |
| GET | `/bookings` | List all bookings |
| GET | `/booking-page` | Booking page config |
| GET | `/settings` | App settings |
| GET | `/subscriptions` | List subscriptions |
| GET | `/export-ical` | Export all calendars as .ics |
| GET | `/export-ical/:calendar-id` | Export one calendar as .ics |
| POST | `/` | Poke with a JSON action (see below) |

### Public (`/apps/time/api/public/...`)

No authentication required. Only active when the booking page is enabled.

| Method | Path | Description |
|--------|------|-------------|
| GET | `/booking-types` | Active booking types only |
| GET | `/info` | Booking page title, description, ship |
| GET | `/available-slots/:type-id/:date-unix` | Available time slots for a date |
| POST | `/book` | Submit a booking |

### Actions (POST body)

```json
{"action": "create-calendar", "name": "Work", "color": "0x39.8be2", "description": ""}
{"action": "create-event", "title": "Lunch", "calendar-id": "...", "start": 1710000000, "end": 1710003600, "location": "", "description": "", "all-day": false, "reminders": []}
{"action": "move-event", "event-id": "...", "start": 1710000000, "end": 1710003600}
{"action": "import-ical", "cal-name": "Imported", "ics-data": "BEGIN:VCALENDAR..."}
{"action": "subscribe-calendar", "url": "https://...", "cal-name": "Google", "refresh-minutes": 60}
{"action": "set-availability", "rules": [{"day": 1, "start": 540, "end": 1020}]}
{"action": "create-booking-type", "name": "30 Min Call", "duration": 30, "buffer-time": 15, "calendar-id": "...", "color": "0xe0.56a0", "description": "", "active": true, "conflict-calendars": []}
{"action": "book-slot", "booking-type-id": "...", "booker-name": "Alice", "booker-email": "a@b.com", "start": 1710000000, "notes": ""}
{"action": "update-settings", "default-timezone": "UTC", "week-start-day": 0, "default-view": "month", "default-calendar": null}
```

Full action list: `create-calendar`, `update-calendar`, `delete-calendar`, `reorder-calendars`, `create-event`, `update-event`, `delete-event`, `move-event`, `create-booking-type`, `update-booking-type`, `delete-booking-type`, `set-availability`, `toggle-booking-page`, `update-booking-page`, `book-slot`, `cancel-booking`, `confirm-booking`, `update-settings`, `import-ical`, `subscribe-calendar`, `unsubscribe-calendar`, `refresh-subscription`.

## Scry Paths

```
.^(json %gx /=time=/calendars/json)
.^(json %gx /=time=/calendar/<id>/json)
.^(json %gx /=time=/events/<start>/<end>/json)
.^(json %gx /=time=/settings/json)
```

## Booking System

The public booking flow:

1. Define **availability rules** — which days/hours you're bookable (default Mon-Fri 9am-5pm)
2. Create **booking types** — e.g. "30 Min Meeting", with duration, buffer time, and which calendars to check for conflicts
3. Enable the **booking page**
4. Share the link: `https://your-ship.network/apps/time/#/book/<booking-type-id>`

Visitors pick a time slot from a week/day grid. The agent computes available slots by intersecting your availability windows with free time across your conflict calendars (recurring events are expanded). Bookings create real events in your target calendar.

## Subscriptions

Subscribe to any external .ics URL:

```json
{"action": "subscribe-calendar", "url": "https://calendar.google.com/.../basic.ics", "cal-name": "Google Cal", "refresh-minutes": 60}
```

The agent creates a local calendar and periodically fetches + re-imports the .ics data via Iris (Urbit's HTTP client) and Behn (timer). Errors are tracked per-subscription.

## Tests

```
-test /=time=/tests/lib/ical ~
-test /=time=/tests/lib/rrule ~
```

16 tests total: 8 for iCal parsing/generation, 8 for RRULE expansion.

## Development

Edit files in `desk/`, then copy to your pier and commit:

```
cp -r desk/* /path/to/zod/time/
|commit %time
```

If you change the agent state shape, nuke before reinstalling:

```
:time &nuke ~
:time-fileserver &nuke ~
|install our %time
```

## License

MIT
