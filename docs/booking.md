# Public Booking (Calendly-like)

## Overview

The calendar app includes a public booking feature that allows anyone to schedule time with you, similar to Calendly. No Urbit authentication is required for bookers.

## Setup

1. **Create a calendar** for bookings (or use an existing one)
2. **Create a booking type** (e.g., "30 Minute Meeting")
   - Set duration, buffer time, description
   - Associate with a calendar
3. **Set availability** - Define your available hours per day of week
4. **Enable the booking page** - Toggle in Booking Types view

## Booking Flow

### For the host (you):
1. Navigate to `#/booking-types`
2. Create booking types with desired duration and buffer
3. Navigate to `#/availability` and set your available hours
4. Toggle the booking page on
5. Share the booking link: `/apps/calendar/#/book/{booking-type-id}`

### For the booker (public):
1. Visit the booking link
2. See booking type info (name, duration)
3. Select a date from the calendar
4. See available time slots (filtered against existing events)
5. Fill in name, email, optional notes
6. Confirm booking

### What happens:
- An event is created on the host's calendar
- A booking record is stored with booker info
- The time slot becomes unavailable for future bookings

## Slot Availability Algorithm

When a booker requests available slots for a date:

1. Look up the booking type to get duration, buffer time, and target calendar
2. Compute the day of week for the requested date
3. Find matching availability rules for that day
4. For each availability window, generate candidate slots at `(duration + buffer)` minute intervals
5. Fetch all existing events on the target calendar for that date
6. Expand recurring events to get actual occurrences
7. Filter out candidates that overlap with existing events
8. Filter out past time slots
9. Return remaining slots as Unix timestamps

## API Endpoints

All public endpoints are under `/apps/calendar/api/public/`:

- `GET /booking-types` - List active booking types
- `GET /available-slots?type=ID&date=UNIX` - Get available slots
- `GET /info` - Booking page info
- `POST /book` - Book a slot
