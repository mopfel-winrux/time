# Calendar Type Definitions

All types are defined in `sur/calendar.hoon`.

## Identifiers

All IDs are `@uv` (unsigned base-32 values), generated with `sham`.

- `calendar-id` - Unique calendar identifier
- `event-id` - Unique event identifier
- `booking-type-id` - Unique booking type identifier
- `booking-id` - Unique booking identifier

## Core Types

### `calendar`
```hoon
+$  calendar
  $:  name=@t           :: display name
      color=@ux         :: hex color (e.g., 0x39.8be2)
      description=@t    :: optional description
  ==
```

### `event`
```hoon
+$  event
  $:  title=@t          :: event title
      description=@t    :: optional description
      =calendar-id      :: which calendar this belongs to
      start=@da         :: start time (absolute date)
      end=@da           :: end time
      location=@t       :: optional location
      all-day=?         :: is this an all-day event?
      rrule=(unit recurrence-rule)  :: optional recurrence
      reminders=(list reminder)     :: UI-only reminders
      uid=@t            :: iCal UID
      created=@da       :: creation timestamp
      modified=@da      :: last modification timestamp
  ==
```

### `recurrence-rule`
Full RFC 5545 RRULE as a structured type:
```hoon
+$  recurrence-rule
  $:  freq=frequency        :: DAILY/WEEKLY/MONTHLY/YEARLY
      interval=@ud          :: how many freq units between occurrences
      until=(unit @da)      :: optional end date
      count=(unit @ud)      :: optional max occurrences
      byday=(list by-day)   :: e.g., MO,WE,FR
      bymonthday=(list @ud) :: e.g., 1,15
      bymonth=(list @ud)    :: e.g., 1,6,12
      bysetpos=(list @sd)   :: position within set (-1 = last)
      wkst=@ud              :: week start day (0=SU)
      exdates=(set @da)     :: excluded dates
  ==
```

### `reminder`
```hoon
+$  reminder  [minutes-before=@ud]
```

## Booking Types

### `booking-type`
```hoon
+$  booking-type
  $:  name=@t           :: e.g., "30 Minute Meeting"
      duration=@ud      :: duration in minutes
      description=@t    :: what this meeting is for
      color=@ux         :: display color
      =calendar-id      :: events created on this calendar
      buffer-time=@ud   :: minutes buffer between bookings
      active=?          :: whether this type is publicly bookable
  ==
```

### `availability-rule`
```hoon
+$  availability-rule
  $:  day=@ud           :: 0=Sunday through 6=Saturday
      start=@ud         :: minutes from midnight (e.g., 540 = 9:00 AM)
      end=@ud           :: minutes from midnight (e.g., 1020 = 5:00 PM)
  ==
```

### `booking`
```hoon
+$  booking
  $:  =booking-type-id
      =event-id         :: the event created for this booking
      booker-name=@t
      booker-email=@t
      booker-ship=(unit @p)
      start=@da
      notes=@t
      status=booking-status  :: %pending, %confirmed, %cancelled
      created=@da
  ==
```

## Settings
```hoon
+$  settings
  $:  default-timezone=@t       :: timezone string
      week-start-day=@ud        :: 0=Sunday, 1=Monday
      default-view=@t           :: month/week/day/agenda
      default-calendar=(unit calendar-id)
  ==
```

## Actions and Updates

See `api.md` for the JSON representation of all action and update types.
