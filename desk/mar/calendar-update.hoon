/-  calendar
|_  upd=update:calendar
++  grow
  |%
  ++  noun  upd
  ++  json
    ^-  json
    =,  enjs:format
    ?-  -.upd
        %calendar-added
      %-  pairs
      :~  ['type' s+'calendar-added']
          ['calendar-id' s+(scot %uv calendar-id.upd)]
          ['calendar' (calendar-to-json calendar.upd)]
      ==
    ::
        %calendar-updated
      %-  pairs
      :~  ['type' s+'calendar-updated']
          ['calendar-id' s+(scot %uv calendar-id.upd)]
          ['calendar' (calendar-to-json calendar.upd)]
      ==
    ::
        %calendar-removed
      %-  pairs
      :~  ['type' s+'calendar-removed']
          ['calendar-id' s+(scot %uv calendar-id.upd)]
      ==
    ::
        %event-added
      %-  pairs
      :~  ['type' s+'event-added']
          ['event-id' s+(scot %uv event-id.upd)]
          ['event' (event-to-json event.upd)]
      ==
    ::
        %event-updated
      %-  pairs
      :~  ['type' s+'event-updated']
          ['event-id' s+(scot %uv event-id.upd)]
          ['event' (event-to-json event.upd)]
      ==
    ::
        %event-removed
      %-  pairs
      :~  ['type' s+'event-removed']
          ['event-id' s+(scot %uv event-id.upd)]
      ==
    ::
        %booking-created
      %-  pairs
      :~  ['type' s+'booking-created']
          ['booking-id' s+(scot %uv booking-id.upd)]
          ['booking' (booking-to-json booking.upd)]
      ==
    ::
        %booking-cancelled
      %-  pairs
      :~  ['type' s+'booking-cancelled']
          ['booking-id' s+(scot %uv booking-id.upd)]
      ==
    ::
        %booking-confirmed
      %-  pairs
      :~  ['type' s+'booking-confirmed']
          ['booking-id' s+(scot %uv booking-id.upd)]
      ==
    ::
        %settings-updated
      %-  pairs
      :~  ['type' s+'settings-updated']
          (settings-to-pairs settings.upd)
      ==
    ::
        %subscription-added
      %-  pairs
      :~  ['type' s+'subscription-added']
          ['subscription-id' s+(scot %uv subscription-id.upd)]
          ['subscription' (subscription-to-json calendar-subscription.upd)]
      ==
    ::
        %subscription-removed
      %-  pairs
      :~  ['type' s+'subscription-removed']
          ['subscription-id' s+(scot %uv subscription-id.upd)]
      ==
    ::
        %subscription-refreshed
      %-  pairs
      :~  ['type' s+'subscription-refreshed']
          ['subscription-id' s+(scot %uv subscription-id.upd)]
          ['last-fetched' (sect last-fetched.upd)]
          ['error' ?~(error.upd ~ s+u.error.upd)]
      ==
    ::
        %calendar-publicity-changed
      %-  pairs
      :~  ['type' s+'calendar-publicity-changed']
          ['calendar-id' s+(scot %uv calendar-id.upd)]
          ['public' b+public.upd]
      ==
    ::
        %contact-calendar-added
      %-  pairs
      :~  ['type' s+'contact-calendar-added']
          ['contact-calendar-id' s+(scot %uv contact-calendar-id.upd)]
          ['contact-calendar' (contact-calendar-to-json contact-calendar.upd)]
      ==
    ::
        %contact-calendar-removed
      %-  pairs
      :~  ['type' s+'contact-calendar-removed']
          ['contact-calendar-id' s+(scot %uv contact-calendar-id.upd)]
      ==
    ::
        %contact-calendar-updated
      %-  pairs
      :~  ['type' s+'contact-calendar-updated']
          ['contact-calendar-id' s+(scot %uv contact-calendar-id.upd)]
          ['contact-calendar' (contact-calendar-to-json contact-calendar.upd)]
      ==
    ::
        %contact-calendar-toggled
      %-  pairs
      :~  ['type' s+'contact-calendar-toggled']
          ['contact-calendar-id' s+(scot %uv contact-calendar-id.upd)]
          ['enabled' b+enabled.upd]
      ==
    ::
        %discovered-calendars
      %-  pairs
      :~  ['type' s+'discovered-calendars']
          ['ship' s+(scot %p ship.upd)]
          :-  'calendars'
          :-  %a
          %+  turn  calendars.upd
          |=  [cid=calendar-id:calendar cal=calendar:calendar]
          %-  pairs
          :~  ['calendar-id' s+(scot %uv cid)]
              ['name' s+name.cal]
              ['color' s+(scot %ux color.cal)]
              ['description' s+description.cal]
          ==
      ==
    ==
  --
++  grab
  |%
  ++  noun  update:calendar
  --
++  grad  %noun
::
++  calendar-to-json
  |=  cal=calendar:calendar
  ^-  json
  =,  enjs:format
  %-  pairs
  :~  ['name' s+name.cal]
      ['color' s+(scot %ux color.cal)]
      ['description' s+description.cal]
      ['public' b+public.cal]
  ==
::
++  event-to-json
  |=  ev=event:calendar
  ^-  json
  =,  enjs:format
  %-  pairs
  :~  ['title' s+title.ev]
      ['description' s+description.ev]
      ['calendar-id' s+(scot %uv calendar-id.ev)]
      ['start' (sect start.ev)]
      ['end' (sect end.ev)]
      ['location' s+location.ev]
      ['all-day' b+all-day.ev]
      ['uid' s+uid.ev]
      ['created' (sect created.ev)]
      ['modified' (sect modified.ev)]
      :-  'reminders'
      :-  %a
      %+  turn  reminders.ev
      |=  r=reminder:calendar
      (pairs ~[['minutes-before' (numb minutes-before.r)]])
  ==
::
++  booking-to-json
  |=  bk=booking:calendar
  ^-  json
  =,  enjs:format
  %-  pairs
  :~  ['booking-type-id' s+(scot %uv booking-type-id.bk)]
      ['event-id' s+(scot %uv event-id.bk)]
      ['booker-name' s+booker-name.bk]
      ['booker-email' s+booker-email.bk]
      ['start' (sect start.bk)]
      ['notes' s+notes.bk]
      ['status' s+status.bk]
      ['created' (sect created.bk)]
  ==
::
++  subscription-to-json
  |=  sub=calendar-subscription:calendar
  ^-  json
  =,  enjs:format
  %-  pairs
  :~  ['url' s+url.sub]
      ['calendar-id' s+(scot %uv calendar-id.sub)]
      ['refresh-interval' (numb (div refresh-interval.sub ~m1))]
      ['last-fetched' (sect last-fetched.sub)]
      ['error' ?~(error.sub ~ s+u.error.sub)]
  ==
::
++  contact-calendar-to-json
  |=  cc=contact-calendar:calendar
  ^-  json
  =,  enjs:format
  %-  pairs
  :~  ['ship' s+(scot %p ship.cc)]
      ['calendar-id' s+(scot %uv calendar-id.cc)]
      ['name' s+name.calendar.cc]
      ['color' s+(scot %ux color.calendar.cc)]
      ['description' s+description.calendar.cc]
      ['enabled' b+enabled.cc]
      ['last-updated' (sect last-updated.cc)]
  ==
::
++  settings-to-pairs
  |=  s=settings:calendar
  ^-  [@t json]
  =,  enjs:format
  :-  'settings'
  %-  pairs
  :~  ['default-timezone' s+default-timezone.s]
      ['week-start-day' (numb week-start-day.s)]
      ['default-view' s+default-view.s]
      :-  'default-calendar'
      ?~  default-calendar.s  ~
      s+(scot %uv u.default-calendar.s)
  ==
--
