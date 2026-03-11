::  calendar: type definitions for the calendar agent
::
|%
::  identifiers
::
+$  calendar-id  @uv
+$  event-id  @uv
+$  booking-type-id  @uv
+$  booking-id  @uv
::
::  core types
::
+$  calendar
  $:  name=@t
      color=@ux
      description=@t
  ==
::
+$  event
  $:  title=@t
      description=@t
      =calendar-id
      start=@da
      end=@da
      location=@t
      all-day=?
      rrule=(unit recurrence-rule)
      reminders=(list reminder)
      uid=@t
      created=@da
      modified=@da
  ==
::
+$  recurrence-rule
  $:  freq=frequency
      interval=@ud
      until=(unit @da)
      count=(unit @ud)
      byday=(list by-day)
      bymonthday=(list @ud)
      bymonth=(list @ud)
      bysetpos=(list @sd)
      wkst=@ud
      exdates=(set @da)
  ==
::
+$  frequency
  $?  %daily
      %weekly
      %monthly
      %yearly
  ==
::
+$  by-day
  $:  ord=(unit @sd)
      day=@ud
  ==
::
+$  reminder
  [minutes-before=@ud]
::
::  booking types
::
+$  booking-type
  $:  name=@t
      duration=@ud
      description=@t
      color=@ux
      =calendar-id
      buffer-time=@ud
      active=?
      conflict-calendars=(list calendar-id)
  ==
::
+$  availability-rule
  $:  day=@ud
      start=@ud
      end=@ud
  ==
::
+$  booking
  $:  =booking-type-id
      =event-id
      booker-name=@t
      booker-email=@t
      booker-ship=(unit @p)
      start=@da
      notes=@t
      status=booking-status
      created=@da
  ==
::
+$  booking-status
  $?  %pending
      %confirmed
      %cancelled
  ==
::
+$  subscription-id  @uv
::
+$  calendar-subscription
  $:  url=@t
      =calendar-id
      refresh-interval=@dr
      last-fetched=@da
      error=(unit @t)
  ==
::
+$  booking-page
  $:  enabled=?
      title=@t
      description=@t
  ==
::
::  settings
::
+$  settings
  $:  default-timezone=@t
      week-start-day=@ud
      default-view=@t
      default-calendar=(unit calendar-id)
  ==
::
::  agent state
::
+$  state-0
  $:  %0
      calendars=(map calendar-id calendar)
      calendar-order=(list calendar-id)
      events=(map event-id event)
      booking-types=(map booking-type-id booking-type)
      availability-rules=(list availability-rule)
      bookings=(map booking-id booking)
      subscriptions=(map subscription-id calendar-subscription)
      =booking-page
      =settings
  ==
::
::  poke actions
::
+$  action
  $%  [%create-calendar name=@t color=@ux description=@t]
      [%update-calendar =calendar-id name=@t color=@ux description=@t]
      [%delete-calendar =calendar-id]
      [%reorder-calendars order=(list calendar-id)]
  ::
      [%create-event =event]
      [%update-event =event-id =event]
      [%delete-event =event-id]
      [%move-event =event-id start=@da end=@da]
  ::
      [%create-booking-type =booking-type]
      [%update-booking-type =booking-type-id =booking-type]
      [%delete-booking-type =booking-type-id]
  ::
      [%set-availability rules=(list availability-rule)]
  ::
      [%toggle-booking-page ~]
      [%update-booking-page title=@t description=@t]
  ::
      [%book-slot =booking-type-id booker-name=@t booker-email=@t booker-ship=(unit @p) start=@da notes=@t]
      [%cancel-booking =booking-id]
      [%confirm-booking =booking-id]
  ::
      [%update-settings =settings]
  ::
      [%import-ical cal-name=@t ics-data=@t]
      [%export-ical =calendar-id]
  ::
      [%subscribe-calendar url=@t cal-name=@t refresh-interval=@dr]
      [%unsubscribe-calendar =subscription-id]
      [%refresh-subscription =subscription-id]
  ==
::
::  subscription updates
::
+$  update
  $%  [%calendar-added =calendar-id =calendar]
      [%calendar-updated =calendar-id =calendar]
      [%calendar-removed =calendar-id]
  ::
      [%event-added =event-id =event]
      [%event-updated =event-id =event]
      [%event-removed =event-id]
  ::
      [%booking-created =booking-id =booking]
      [%booking-cancelled =booking-id]
      [%booking-confirmed =booking-id]
  ::
      [%settings-updated =settings]
  ::
      [%subscription-added =subscription-id =calendar-subscription]
      [%subscription-removed =subscription-id]
      [%subscription-refreshed =subscription-id last-fetched=@da error=(unit @t)]
  ==
--
