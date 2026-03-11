# Calendar HTTP API

## Authenticated Endpoints

All authenticated endpoints require Urbit login cookies. Base path: `/apps/calendar/api/`

### GET Endpoints

#### `GET /calendars`
Returns all calendars with event counts.
```json
{
  "calendars": [
    {
      "id": "0v1abc...",
      "name": "Work",
      "color": "0x39.8be2",
      "description": "Work calendar",
      "event-count": 42
    }
  ]
}
```

#### `GET /calendar/:id`
Returns a single calendar.

#### `GET /events?start=X&end=Y&cal=Z`
Returns events in a date range (Unix timestamps). Optional `cal` filter by calendar ID. Recurring events are expanded into individual occurrences.
```json
{
  "events": [
    {
      "id": "0v2def...",
      "title": "Team Standup",
      "description": "",
      "calendar-id": "0v1abc...",
      "start": 1709726400,
      "end": 1709730000,
      "location": "Room A",
      "all-day": false,
      "has-rrule": true,
      "uid": "standup@urbit",
      "reminders": [{"minutes-before": 15}]
    }
  ]
}
```

#### `GET /event/:id`
Returns a single event with full details.

#### `GET /booking-types`
Returns all booking types.

#### `GET /availability`
Returns availability rules.

#### `GET /bookings`
Returns all bookings.

#### `GET /settings`
Returns user settings.

#### `GET /booking-page`
Returns booking page configuration.

#### `GET /export-ical/:calendar-id`
Downloads calendar as .ics file.

#### `GET /export-ical`
Downloads all calendars as a single .ics file.

### POST Endpoint

`POST /apps/calendar/api` with JSON body containing an `action` field.

#### Calendar Actions
```json
{"action": "create-calendar", "name": "Work", "color": "0x39.8be2", "description": ""}
{"action": "update-calendar", "calendar-id": "0v1abc...", "name": "Work", "color": "0x39.8be2", "description": ""}
{"action": "delete-calendar", "calendar-id": "0v1abc..."}
{"action": "reorder-calendars", "order": ["0v1abc...", "0v2def..."]}
```

#### Event Actions
```json
{"action": "create-event", "title": "Meeting", "description": "", "calendar-id": "0v1abc...", "start": 1709726400, "end": 1709730000, "location": "", "all-day": false, "reminders": []}
{"action": "update-event", "event-id": "0v2def...", "title": "Meeting", ...}
{"action": "delete-event", "event-id": "0v2def..."}
{"action": "move-event", "event-id": "0v2def...", "start": 1709726400, "end": 1709730000}
```

#### Booking Actions
```json
{"action": "create-booking-type", "name": "30min", "duration": 30, "description": "", "color": "0xe0.56a0", "calendar-id": "0v1abc...", "buffer-time": 15, "active": true}
{"action": "set-availability", "rules": [{"day": 1, "start": 540, "end": 1020}]}
{"action": "toggle-booking-page"}
{"action": "book-slot", "booking-type-id": "0v3ghi...", "booker-name": "Alice", "booker-email": "alice@example.com", "start": 1709726400, "notes": ""}
```

#### Settings & Import
```json
{"action": "update-settings", "default-timezone": "UTC", "week-start-day": 0, "default-view": "month"}
{"action": "import-ical", "cal-name": "Imported", "ics-data": "BEGIN:VCALENDAR..."}
```

## Public Endpoints

No auth required. Base path: `/apps/calendar/api/public/`

#### `GET /booking-types`
Returns active booking types (limited info).

#### `GET /available-slots?type=X&date=Y`
Returns available time slots for a booking type on a given date (Unix timestamp).

#### `GET /info`
Returns booking page title, description, and host ship.

#### `POST /book`
Book a slot.
```json
{
  "booking-type-id": "0v3ghi...",
  "booker-name": "Alice",
  "booker-email": "alice@example.com",
  "start": 1709726400,
  "notes": "Looking forward to it"
}
```
