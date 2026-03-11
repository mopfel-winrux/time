::  ical: iCal (.ics) parser and generator library
::
::    parses and generates RFC 5545 VCALENDAR/VEVENT components.
::
/-  calendar
|%
::  +parse-ical: parse ics text into events and optional calendar metadata
::
++  parse-ical
  |=  ics=@t
  ^-  [(list event:calendar) (unit [name=@t description=@t])]
  =/  lines=(list @t)  (unfold-lines (to-lines ics))
  =/  events=(list event:calendar)  ~
  =/  cal-name=@t  ''
  =/  cal-desc=@t  ''
  =/  in-vevent=?  |
  =/  cur-props=(map @t @t)  ~
  |-
  ?~  lines
    [(flop events) ?:(=('' cal-name) ~ `[cal-name cal-desc])]
  =/  line=@t  i.lines
  ?:  =(line 'BEGIN:VEVENT')
    $(lines t.lines, in-vevent &, cur-props ~)
  ?:  =(line 'END:VEVENT')
    =/  ev=event:calendar  (props-to-event cur-props)
    $(lines t.lines, in-vevent |, events [ev events])
  ?:  in-vevent
    =/  [key=@t val=@t]  (parse-prop line)
    $(lines t.lines, cur-props (~(put by cur-props) key val))
  ::  outside VEVENT, look for calendar properties
  =/  [key=@t val=@t]  (parse-prop line)
  ?:  =(key 'x-wr-calname')
    $(lines t.lines, cal-name val)
  ?:  =(key 'x-wr-caldesc')
    $(lines t.lines, cal-desc val)
  $(lines t.lines)
::
::  +generate-ical: generate ics text from calendar and events
::
++  generate-ical
  |=  [cal=calendar:calendar events=(list event:calendar)]
  ^-  @t
  =/  header=tape
    ;:  welp
      "BEGIN:VCALENDAR\0d\0a"
      "VERSION:2.0\0d\0a"
      "PRODID:-//Urbit//Calendar//EN\0d\0a"
      "X-WR-CALNAME:{(trip name.cal)}\0d\0a"
    ==
  =/  body=tape
    %-  zing
    %+  turn  events
    |=  ev=event:calendar
    ^-  tape
    =/  desc=tape
      ?:  =('' description.ev)  ""
      "DESCRIPTION:{(trip description.ev)}\0d\0a"
    =/  loc=tape
      ?:  =('' location.ev)  ""
      "LOCATION:{(trip location.ev)}\0d\0a"
    =/  dtstart=tape
      ?:  all-day.ev
        "DTSTART;VALUE=DATE:{(da-to-ical-date start.ev)}\0d\0a"
      "DTSTART:{(da-to-ical start.ev)}\0d\0a"
    =/  dtend=tape
      ?:  all-day.ev
        "DTEND;VALUE=DATE:{(da-to-ical-date end.ev)}\0d\0a"
      "DTEND:{(da-to-ical end.ev)}\0d\0a"
    =/  rrule-str=tape
      ?~  rrule.ev  ""
      "RRULE:{(rrule-to-ical u.rrule.ev)}\0d\0a"
    =/  alarms=tape
      %-  zing
      %+  turn  reminders.ev
      |=  r=reminder:calendar
      ;:  welp
        "BEGIN:VALARM\0d\0a"
        "TRIGGER:-PT{((d-co:co 1) minutes-before.r)}M\0d\0a"
        "ACTION:DISPLAY\0d\0a"
        "END:VALARM\0d\0a"
      ==
    ;:  welp
      "BEGIN:VEVENT\0d\0a"
      "UID:{(trip uid.ev)}\0d\0a"
      "SUMMARY:{(trip title.ev)}\0d\0a"
      desc
      loc
      dtstart
      dtend
      rrule-str
      alarms
      "END:VEVENT\0d\0a"
    ==
  (crip "{header}{body}END:VCALENDAR\0d\0a")
::
::  helper arms
::
::  +to-lines: split text on CRLF or LF
::
++  to-lines
  |=  txt=@t
  ^-  (list @t)
  =/  tx=tape  (trip txt)
  =|  acc=(list @t)
  =|  cur=tape
  |-
  ?~  tx
    ?~  cur  (flop acc)
    (flop [(crip (flop cur)) acc])
  ?:  ?&(=('\0d' i.tx) ?=(^ t.tx) =('\0a' i.t.tx))
    $(tx t.t.tx, acc [(crip (flop cur)) acc], cur ~)
  ?:  =('\0a' i.tx)
    $(tx t.tx, acc [(crip (flop cur)) acc], cur ~)
  $(tx t.tx, cur [i.tx cur])
::
::  +unfold-lines: handle RFC 5545 line continuations
::    lines starting with space or tab are continuations
::
++  unfold-lines
  |=  lines=(list @t)
  ^-  (list @t)
  =|  acc=(list @t)
  =/  prev=tape  ~
  |-
  ?~  lines
    ?~  prev  (flop acc)
    (flop [(crip prev) acc])
  =/  line=tape  (trip i.lines)
  ?:  ?&(?=(^ line) ?|(=(i.line ' ') =(i.line '\09')))
    ::  continuation line: append without leading whitespace
    $(lines t.lines, prev (welp prev t.line))
  ::  new line: flush prev
  ?~  prev
    $(lines t.lines, prev line)
  $(lines t.lines, prev line, acc [(crip prev) acc])
::
::  +parse-prop: split a property line into key and value
::    handles parameters (e.g., DTSTART;VALUE=DATE:20240101)
::
++  parse-prop
  |=  line=@t
  ^-  [@t @t]
  =/  len=@ud  (met 3 line)
  =/  idx=@ud  0
  |-
  ?:  =(idx len)  [line '']
  ?:  =(58 (cut 3 [idx 1] line))  :: 58 = ':'
    =/  raw-key=@t  (end [3 idx] line)
    =/  val=@t  (rsh [3 +(idx)] line)
    ::  strip parameters: take only the part before ';'
    =/  base-key=@t
      =/  klen=@ud  (met 3 raw-key)
      =/  j=@ud  0
      |-
      ?:  =(j klen)  raw-key
      ?:  =(59 (cut 3 [j 1] raw-key))  (end [3 j] raw-key)  :: 59 = ';'
      $(j +(j))
    [(crip (cass (trip base-key))) val]
  $(idx +(idx))
::
::  +props-to-event: convert property map to event
::
++  props-to-event
  |=  props=(map @t @t)
  ^-  event:calendar
  =/  title=@t  (fall (~(get by props) 'summary') '')
  =/  desc=@t   (fall (~(get by props) 'description') '')
  =/  loc=@t    (fall (~(get by props) 'location') '')
  =/  uid=@t    (fall (~(get by props) 'uid') '')
  =/  dtstart-raw=@t  (fall (~(get by props) 'dtstart') '')
  =/  dtend-raw=@t    (fall (~(get by props) 'dtend') '')
  =/  all-day=?  (is-date-only dtstart-raw)
  =/  start=@da  (parse-dt dtstart-raw)
  =/  end=@da    ?:(=('' dtend-raw) (add start ?:(all-day ~d1 ~h1)) (parse-dt dtend-raw))
  =/  rrule-raw=@t  (fall (~(get by props) 'rrule') '')
  =/  rrule=(unit recurrence-rule:calendar)
    ?:(=('' rrule-raw) ~ `(parse-rrule rrule-raw))
  :*  title
      desc
      *calendar-id:calendar
      start
      end
      loc
      all-day
      rrule
      ~
      uid
      start
      start
  ==
::
::  +is-date-only: check if a date string is date-only (8 digits)
::
++  is-date-only
  |=  dt=@t
  ^-  ?
  =(8 (met 3 dt))
::
::  +parse-dt: parse iCal datetime (YYYYMMDDTHHMMSSZ or YYYYMMDD)
::
++  parse-dt
  |=  dt=@t
  ^-  @da
  =/  len=@ud  (met 3 dt)
  ?:  (lth len 8)  *@da
  =/  yr=@ud   (rash (end [3 4] dt) dum:ag)
  =/  mo=@ud   (rash (cut 3 [4 2] dt) dum:ag)
  =/  dy=@ud   (rash (cut 3 [6 2] dt) dum:ag)
  ?:  (lte len 8)
    =/  dat=date  [[& yr] mo [dy 0 0 0 ~]]
    (year dat)
  ::  has time component — skip 'T' at position 8
  =/  hr=@ud   ?:((lth len 11) 0 (rash (cut 3 [9 2] dt) dum:ag))
  =/  mn=@ud   ?:((lth len 13) 0 (rash (cut 3 [11 2] dt) dum:ag))
  =/  sc=@ud   ?:((lth len 15) 0 (rash (cut 3 [13 2] dt) dum:ag))
  =/  dat=date  [[& yr] mo [dy hr mn sc ~]]
  (year dat)
::
::  +da-to-ical: convert @da to iCal datetime string
::
++  da-to-ical
  |=  d=@da
  ^-  tape
  =/  date=date  (yore d)
  ;:  welp
    (pad4 y.date)
    (pad2 m.date)
    (pad2 d.t.date)
    "T"
    (pad2 h.t.date)
    (pad2 m.t.date)
    (pad2 s.t.date)
    "Z"
  ==
::
::  +da-to-ical-date: convert @da to iCal date-only string
::
++  da-to-ical-date
  |=  d=@da
  ^-  tape
  =/  date=date  (yore d)
  ;:  welp
    (pad4 y.date)
    (pad2 m.date)
    (pad2 d.t.date)
  ==
::
++  pad2
  |=  n=@ud
  ^-  tape
  ?:  (lth n 10)  "0{((d-co:co 1) n)}"
  ((d-co:co 1) n)
::
++  pad4
  |=  n=@ud
  ^-  tape
  ?:  (lth n 10)    "000{((d-co:co 1) n)}"
  ?:  (lth n 100)   "00{((d-co:co 1) n)}"
  ?:  (lth n 1.000)  "0{((d-co:co 1) n)}"
  ((d-co:co 1) n)
::
::  +parse-rrule: parse RRULE string into recurrence-rule
::
++  parse-rrule
  |=  rrule-str=@t
  ^-  recurrence-rule:calendar
  =/  parts=(list @t)  (split-on rrule-str ';')
  =|  rule=recurrence-rule:calendar
  =.  interval.rule  1
  |-
  ?~  parts  rule
  =/  [key=@t val=@t]  (split-kv i.parts)
  =.  rule
    ?+  key  rule
      %'FREQ'
        %=  rule  freq
          ?+  val  %daily
            %'DAILY'    %daily
            %'WEEKLY'   %weekly
            %'MONTHLY'  %monthly
            %'YEARLY'   %yearly
          ==
        ==
      %'INTERVAL'  rule(interval (rash val dum:ag))
      %'COUNT'     rule(count `(rash val dum:ag))
      %'UNTIL'     rule(until `(parse-dt val))
      %'WKST'      rule(wkst (day-name-to-num val))
      %'BYDAY'     rule(byday (parse-byday val))
      %'BYMONTHDAY'  rule(bymonthday (parse-numlist val))
      %'BYMONTH'     rule(bymonth (parse-numlist val))
      %'BYSETPOS'    rule(bysetpos (parse-sdlist val))
    ==
  $(parts t.parts)
::
::  +rrule-to-ical: convert recurrence-rule to RRULE string
::
++  rrule-to-ical
  |=  rule=recurrence-rule:calendar
  ^-  tape
  =/  parts=(list tape)
    :~  "FREQ={(trip (freq-to-text freq.rule))}"
    ==
  =?  parts  (gth interval.rule 1)
    (snoc parts "INTERVAL={((d-co:co 1) interval.rule)}")
  =?  parts  ?=(^ until.rule)
    (snoc parts "UNTIL={(da-to-ical u.until.rule)}")
  =?  parts  ?=(^ count.rule)
    (snoc parts "COUNT={((d-co:co 1) u.count.rule)}")
  =?  parts  ?=(^ byday.rule)
    (snoc parts "BYDAY={(byday-to-text byday.rule)}")
  =?  parts  ?=(^ bymonthday.rule)
    (snoc parts "BYMONTHDAY={(numlist-to-text bymonthday.rule)}")
  =?  parts  ?=(^ bymonth.rule)
    (snoc parts "BYMONTH={(numlist-to-text bymonth.rule)}")
  (zing (join ";" parts))
::
++  freq-to-text
  |=  f=frequency:calendar
  ^-  @t
  ?-  f
    %daily    'DAILY'
    %weekly   'WEEKLY'
    %monthly  'MONTHLY'
    %yearly   'YEARLY'
  ==
::
++  byday-to-text
  |=  days=(list by-day:calendar)
  ^-  tape
  %-  zing
  %+  join  ","
  %+  turn  days
  |=  bd=by-day:calendar
  ^-  tape
  %+  welp
    ?~  ord.bd  ""
    ?:  (syn:si u.ord.bd)
      ((d-co:co 1) (abs:si u.ord.bd))
    "-{((d-co:co 1) (abs:si u.ord.bd))}"
  (trip (num-to-day-name day.bd))
::
++  numlist-to-text
  |=  nums=(list @ud)
  ^-  tape
  %-  zing
  (join "," (turn nums |=(n=@ud ((d-co:co 1) n))))
::
::  string utilities
::
++  split-on
  |=  [txt=@t sep=@t]
  ^-  (list @t)
  =/  len=@ud  (met 3 txt)
  =/  sep-char=@  (end [3 1] sep)
  =|  acc=(list @t)
  =/  start=@ud  0
  =/  idx=@ud  0
  |-
  ?:  =(idx len)
    ?:  =(start idx)  (flop acc)
    (flop [(cut 3 [start (sub idx start)] txt) acc])
  ?:  =(sep-char (cut 3 [idx 1] txt))
    $(idx +(idx), start +(idx), acc [(cut 3 [start (sub idx start)] txt) acc])
  $(idx +(idx))
::
++  split-kv
  |=  txt=@t
  ^-  [@t @t]
  =/  len=@ud  (met 3 txt)
  =/  idx=@ud  0
  |-
  ?:  =(idx len)  [txt '']
  ?:  =(61 (cut 3 [idx 1] txt))  :: 61 = '='
    [(crip (cuss (trip (end [3 idx] txt)))) (rsh [3 +(idx)] txt)]
  $(idx +(idx))
::
++  day-name-to-num
  |=  name=@t
  ^-  @ud
  ?+  name  0
    %'SU'  0
    %'MO'  1
    %'TU'  2
    %'WE'  3
    %'TH'  4
    %'FR'  5
    %'SA'  6
  ==
::
++  num-to-day-name
  |=  n=@ud
  ^-  @t
  ?+  n  'SU'
    %0  'SU'
    %1  'MO'
    %2  'TU'
    %3  'WE'
    %4  'TH'
    %5  'FR'
    %6  'SA'
  ==
::
++  parse-byday
  |=  val=@t
  ^-  (list by-day:calendar)
  =/  parts=(list @t)  (split-on val ',')
  %+  turn  parts
  |=  part=@t
  ^-  by-day:calendar
  =/  len=@ud  (met 3 part)
  ?:  (lte len 2)
    [~ (day-name-to-num part)]
  ::  has ordinal prefix
  =/  day-str=@t  (rsh [3 (sub len 2)] part)
  =/  ord-cord=@t  (end [3 (sub len 2)] part)
  =/  neg=?  =(45 (end [3 1] ord-cord))
  =/  num-cord=@t  ?:(neg (rsh [3 1] ord-cord) ord-cord)
  =/  num=@ud  (rash num-cord dum:ag)
  =/  ord=@sd  ?:(neg (new:si | num) (new:si & num))
  [`ord (day-name-to-num day-str)]
::
++  parse-numlist
  |=  val=@t
  ^-  (list @ud)
  =/  parts=(list @t)  (split-on val ',')
  (turn parts |=(p=@t (rash p dum:ag)))
::
++  parse-sdlist
  |=  val=@t
  ^-  (list @sd)
  =/  parts=(list @t)  (split-on val ',')
  %+  turn  parts
  |=  p=@t
  ^-  @sd
  ?:  =(45 (end [3 1] p))
    (new:si | (rash (rsh [3 1] p) dum:ag))
  (new:si & (rash p dum:ag))
--
