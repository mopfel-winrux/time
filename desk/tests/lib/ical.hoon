::  tests for lib/ical.hoon
::
/-  calendar
/+  *test, ical
|%
::  test basic ical parsing
::
++  test-parse-basic
  =/  ics=@t
    %-  crip
    ;:  welp
      "BEGIN:VCALENDAR\0d\0a"
      "VERSION:2.0\0d\0a"
      "X-WR-CALNAME:Test Calendar\0d\0a"
      "BEGIN:VEVENT\0d\0a"
      "SUMMARY:Test Event\0d\0a"
      "DTSTART:20240115T090000Z\0d\0a"
      "DTEND:20240115T100000Z\0d\0a"
      "UID:test-uid-1@urbit\0d\0a"
      "END:VEVENT\0d\0a"
      "END:VCALENDAR\0d\0a"
    ==
  =/  [evts=(list event:calendar) cal-meta=(unit [name=@t description=@t])]
    (parse-ical:ical ics)
  ;:  weld
    %+  expect-eq
      !>  1
      !>  (lent evts)
    %+  expect-eq
      !>  'Test Event'
      !>  ?~(evts '' title.i.evts)
    %+  expect-eq
      !>  'test-uid-1@urbit'
      !>  ?~(evts '' uid.i.evts)
    %+  expect-eq
      !>  &
      !>  ?=(^ cal-meta)
    %+  expect-eq
      !>  'Test Calendar'
      !>  ?~(cal-meta '' name.u.cal-meta)
  ==
::  test generate and re-parse round trip
::
++  test-roundtrip
  =/  cal=calendar:calendar
    ['Round Trip Cal' 0x0 'test desc']
  =/  ev=event:calendar
    :*  'Roundtrip Event'
        'A description'
        *calendar-id:calendar
        ~2024.3.1..14.00.00
        ~2024.3.1..15.00.00
        'Room 42'
        |
        ~
        ~
        'roundtrip-uid@test'
        ~2024.1.1
        ~2024.1.1
    ==
  =/  ics=@t  (generate-ical:ical cal ~[ev])
  =/  [evts=(list event:calendar) *]  (parse-ical:ical ics)
  ;:  weld
    %+  expect-eq
      !>  1
      !>  (lent evts)
    %+  expect-eq
      !>  'Roundtrip Event'
      !>  ?~(evts '' title.i.evts)
    %+  expect-eq
      !>  'Room 42'
      !>  ?~(evts '' location.i.evts)
    %+  expect-eq
      !>  'roundtrip-uid@test'
      !>  ?~(evts '' uid.i.evts)
  ==
::  test date parsing
::
++  test-parse-date
  ;:  weld
    ::  full datetime
    %+  expect-eq
      !>  ~2024.1.15..09.00.00
      !>  (parse-dt:ical '20240115T090000Z')
    ::  date only
    %+  expect-eq
      !>  ~2024.1.15
      !>  (parse-dt:ical '20240115')
  ==
::  test line unfolding
::
++  test-unfold
  =/  lines=(list @t)
    ~['SUMMARY:Long' ' continuation' 'LOCATION:Here']
  =/  result=(list @t)  (unfold-lines:ical lines)
  ;:  weld
    %+  expect-eq
      !>  2
      !>  (lent result)
    %+  expect-eq
      !>  'SUMMARY:Longcontinuation'
      !>  ?~(result '' i.result)
    %+  expect-eq
      !>  'LOCATION:Here'
      !>  ?~(result '' ?~(t.result '' i.t.result))
  ==
::  test multiple events
::
++  test-parse-multiple
  =/  ics=@t
    %-  crip
    ;:  welp
      "BEGIN:VCALENDAR\0d\0a"
      "BEGIN:VEVENT\0d\0a"
      "SUMMARY:Event 1\0d\0a"
      "DTSTART:20240101T100000Z\0d\0a"
      "END:VEVENT\0d\0a"
      "BEGIN:VEVENT\0d\0a"
      "SUMMARY:Event 2\0d\0a"
      "DTSTART:20240102T100000Z\0d\0a"
      "END:VEVENT\0d\0a"
      "END:VCALENDAR\0d\0a"
    ==
  =/  [evts=(list event:calendar) *]
    (parse-ical:ical ics)
  %+  expect-eq
    !>  2
    !>  (lent evts)
--
