::  rrule: RFC 5545 RRULE expansion library
::
::    expands recurrence rules into concrete occurrence dates
::    within a given query range.
::
/-  calendar
|%
::  +expand: generate occurrences of a recurring event within a date range
::
::    takes a recurrence-rule, event start/end, and query range,
::    returns list of [start end] pairs for each occurrence.
::
++  expand
  |=  $:  rule=recurrence-rule:calendar
          dtstart=@da
          dtend=@da
          range-start=@da
          range-end=@da
      ==
  ^-  (list [@da @da])
  =/  duration=@dr  (sub dtend dtstart)
  =/  candidates=(list @da)
    (generate-candidates rule dtstart range-end)
  ::  apply BY* filters
  =/  filtered=(list @da)
    (apply-filters rule candidates)
  ::  apply UNTIL/COUNT limits
  =/  limited=(list @da)
    (apply-limits rule filtered dtstart)
  ::  remove exdates
  =/  cleaned=(list @da)
    (remove-exdates exdates.rule limited)
  ::  clip to query range and build pairs
  %+  murn  cleaned
  |=  s=@da
  ^-  (unit [@da @da])
  =/  e=@da  (add s duration)
  ::  event overlaps range if it starts before range-end and ends after range-start
  ?.  ?&((lth s range-end) (gth e range-start))
    ~
  `[s e]
::
::  +generate-candidates: step through FREQ*INTERVAL from dtstart
::
++  generate-candidates
  |=  [rule=recurrence-rule:calendar dtstart=@da limit=@da]
  ^-  (list @da)
  =/  max-count=@ud  2.000
  =/  step=@dr
    ?-  freq.rule
      %daily   (mul ~d1 (max 1 interval.rule))
      %weekly  (mul ~d7 (max 1 interval.rule))
      %monthly  ~d1
      %yearly   ~d1
    ==
  ?:  ?=(?(%monthly %yearly) freq.rule)
    (generate-by-month rule dtstart limit max-count)
  =|  acc=(list @da)
  =/  cur=@da  dtstart
  =/  n=@ud  0
  |-
  ?:  (gte n max-count)  (flop acc)
  ?:  (gth cur limit)  (flop acc)
  =.  acc  [cur acc]
  $(cur (add cur step), n +(n))
::
::  +generate-by-month: handle monthly/yearly recurrence
::
++  generate-by-month
  |=  [rule=recurrence-rule:calendar dtstart=@da limit=@da mx=@ud]
  ^-  (list @da)
  =/  [sy=@ud sm=@ud sd=@ud]  (yore-date dtstart)
  =/  st=@dr  (time-of-day dtstart)
  =/  intv=@ud  (max 1 interval.rule)
  =|  acc=(list @da)
  =/  cy=@ud  sy
  =/  cm=@ud  sm
  =/  n=@ud  0
  |-
  ?:  (gte n mx)  (flop acc)
  ::  construct candidate date
  =/  target-day=@ud
    ?:  ?=(^ bymonthday.rule)
      i.bymonthday.rule
    sd
  =/  dim=@ud  (days-in-month cy cm)
  =/  clamped=@ud  (min target-day dim)
  =/  candidate=@da  (to-date cy cm clamped st)
  ?:  (gth candidate limit)  (flop acc)
  ?:  (lth candidate dtstart)
    ::  advance
    ?:  ?=(%monthly freq.rule)
      =/  nm=@ud  (add cm intv)
      =/  ny=@ud  (add cy (div (dec nm) 12))
      =/  nm=@ud  (add (mod (dec nm) 12) 1)
      $(cy ny, cm nm, n +(n))
    ::  yearly
    $(cy (add cy intv), n +(n))
  =.  acc  [candidate acc]
  ?:  ?=(%monthly freq.rule)
    =/  nm=@ud  (add cm intv)
    =/  ny=@ud  (add cy (div (dec nm) 12))
    =/  nm=@ud  (add (mod (dec nm) 12) 1)
    $(cy ny, cm nm, n +(n))
  ::  yearly
  $(cy (add cy intv), n +(n))
::
::  +apply-filters: filter candidates by BY* rules
::
++  apply-filters
  |=  [rule=recurrence-rule:calendar candidates=(list @da)]
  ^-  (list @da)
  =/  filtered=(list @da)  candidates
  ::  filter by BYMONTH
  =.  filtered
    ?:  =(~ bymonth.rule)  filtered
    %+  skim  filtered
    |=  d=@da
    =/  [* m=@ud *]  (yore-date d)
    (lien bymonth.rule |=(bm=@ud =(bm m)))
  ::  filter by BYDAY
  =.  filtered
    ?:  =(~ byday.rule)  filtered
    %+  skim  filtered
    |=  d=@da
    =/  dow=@ud  (day-of-week d)
    (lien byday.rule |=(bd=by-day:calendar =(day.bd dow)))
  ::  filter by BYMONTHDAY
  =.  filtered
    ?:  =(~ bymonthday.rule)  filtered
    %+  skim  filtered
    |=  d=@da
    =/  [* * dd=@ud]  (yore-date d)
    (lien bymonthday.rule |=(bmd=@ud =(bmd dd)))
  ::  apply BYSETPOS
  =.  filtered
    ?:  =(~ bysetpos.rule)  filtered
    (apply-setpos bysetpos.rule filtered)
  filtered
::
::  +apply-setpos: filter by BYSETPOS indices
::
++  apply-setpos
  |=  [positions=(list @sd) candidates=(list @da)]
  ^-  (list @da)
  =/  len=@ud  (lent candidates)
  ?:  =(0 len)  ~
  %+  murn  positions
  |=  pos=@sd
  ^-  (unit @da)
  =/  idx=@ud
    ?:  (syn:si pos)
      (dec (abs:si pos))
    (sub len (abs:si pos))
  ?:  (gte idx len)  ~
  `(snag idx candidates)
::
::  +apply-limits: enforce UNTIL and COUNT
::
++  apply-limits
  |=  [rule=recurrence-rule:calendar candidates=(list @da) dtstart=@da]
  ^-  (list @da)
  =/  res=(list @da)  candidates
  ::  apply UNTIL
  =?  res  ?=(^ until.rule)
    (skim res |=(d=@da (lte d u.until.rule)))
  ::  apply COUNT
  =?  res  ?=(^ count.rule)
    (scag u.count.rule res)
  res
::
::  +remove-exdates: remove excluded dates
::
++  remove-exdates
  |=  [exdates=(set @da) candidates=(list @da)]
  ^-  (list @da)
  ?:  =(~ exdates)  candidates
  (skip candidates |=(d=@da (~(has in exdates) d)))
::
::  date utilities
::
::  +day-of-week: 0=Sunday through 6=Saturday
::    epoch: ~2000.1.1 is Saturday (6)
::
++  day-of-week
  |=  d=@da
  ^-  @ud
  =/  days=@ud  (div (sub d ~2000.1.1) ~d1)
  (mod (add days 6) 7)
::
::  +yore-date: extract year, month, day from @da
::
++  yore-date
  |=  d=@da
  ^-  [@ud @ud @ud]
  =/  date=date  (yore d)
  [y.date m.date d.t.date]
::
::  +time-of-day: extract the time portion
::
++  time-of-day
  |=  d=@da
  ^-  @dr
  (mod d ~d1)
::
::  +to-date: construct @da from components
::
++  to-date
  |=  [y=@ud m=@ud d=@ud t=@dr]
  ^-  @da
  =/  dat=date  [[& y] m [d 0 0 0 ~]]
  (add (year dat) t)
::
::  +days-in-month: return number of days in given month
::
++  days-in-month
  |=  [y=@ud m=@ud]
  ^-  @ud
  ?+  m  30
    %1   31
    %2   ?:((is-leap y) 29 28)
    %3   31
    %4   30
    %5   31
    %6   30
    %7   31
    %8   31
    %9   30
    %10  31
    %11  30
    %12  31
  ==
::
::  +is-leap: check if year is a leap year
::
++  is-leap
  |=  y=@ud
  ^-  ?
  ?&  =(0 (mod y 4))
      ?|  !=(0 (mod y 100))
          =(0 (mod y 400))
  ==  ==
--
