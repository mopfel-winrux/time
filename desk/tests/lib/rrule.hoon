::  tests for lib/rrule.hoon
::
/-  calendar
/+  *test, rrule
|%
::  test daily recurrence
::
++  test-daily-basic
  =/  rule=recurrence-rule:calendar
    [%daily 1 ~ ~ ~ ~ ~ ~ 0 ~]
  =/  start=@da  ~2024.1.1
  =/  end=@da    ~2024.1.1..01.00.00
  =/  result=(list [@da @da])
    (expand:rrule rule start end ~2024.1.1 ~2024.1.5)
  ;:  weld
    %+  expect-eq
      !>  4
      !>  (lent result)
    %+  expect-eq
      !>  ~2024.1.1
      !>  -:(snag 0 result)
    %+  expect-eq
      !>  ~2024.1.4
      !>  -:(snag 3 result)
  ==
::  test daily with interval
::
++  test-daily-interval
  =/  rule=recurrence-rule:calendar
    [%daily 2 ~ ~ ~ ~ ~ ~ 0 ~]
  =/  start=@da  ~2024.1.1
  =/  end=@da    ~2024.1.1..01.00.00
  =/  result=(list [@da @da])
    (expand:rrule rule start end ~2024.1.1 ~2024.1.10)
  ;:  weld
    %+  expect-eq
      !>  5
      !>  (lent result)
    %+  expect-eq
      !>  ~2024.1.3
      !>  -:(snag 1 result)
  ==
::  test weekly recurrence
::
++  test-weekly-basic
  =/  rule=recurrence-rule:calendar
    [%weekly 1 ~ ~ ~ ~ ~ ~ 0 ~]
  =/  start=@da  ~2024.1.1
  =/  end=@da    ~2024.1.1..01.00.00
  =/  result=(list [@da @da])
    (expand:rrule rule start end ~2024.1.1 ~2024.2.1)
  ;:  weld
    %+  expect-eq
      !>  ~2024.1.1
      !>  -:(snag 0 result)
    %+  expect-eq
      !>  ~2024.1.8
      !>  -:(snag 1 result)
    %+  expect-eq
      !>  ~2024.1.15
      !>  -:(snag 2 result)
  ==
::  test with count limit
::
++  test-daily-count
  =/  rule=recurrence-rule:calendar
    [%daily 1 ~ `3 ~ ~ ~ ~ 0 ~]
  =/  start=@da  ~2024.1.1
  =/  end=@da    ~2024.1.1..01.00.00
  =/  result=(list [@da @da])
    (expand:rrule rule start end ~2024.1.1 ~2024.12.31)
  %+  expect-eq
    !>  3
    !>  (lent result)
::  test with until limit
::
++  test-daily-until
  =/  rule=recurrence-rule:calendar
    [%daily 1 `~2024.1.5 ~ ~ ~ ~ ~ 0 ~]
  =/  start=@da  ~2024.1.1
  =/  end=@da    ~2024.1.1..01.00.00
  =/  result=(list [@da @da])
    (expand:rrule rule start end ~2024.1.1 ~2024.12.31)
  %+  expect-eq
    !>  5
    !>  (lent result)
::  test day-of-week calculation
::
++  test-day-of-week
  ::  ~2024.1.1 is Monday
  ;:  weld
    %+  expect-eq
      !>  1
      !>  (day-of-week:rrule ~2024.1.1)
    ::  ~2024.1.7 is Sunday
    %+  expect-eq
      !>  0
      !>  (day-of-week:rrule ~2024.1.7)
    ::  ~2024.1.6 is Saturday
    %+  expect-eq
      !>  6
      !>  (day-of-week:rrule ~2024.1.6)
  ==
::  test monthly recurrence
::
++  test-monthly-basic
  =/  rule=recurrence-rule:calendar
    [%monthly 1 ~ ~ ~ ~ ~ ~ 0 ~]
  =/  start=@da  ~2024.1.15
  =/  end=@da    ~2024.1.15..01.00.00
  =/  result=(list [@da @da])
    (expand:rrule rule start end ~2024.1.1 ~2024.4.1)
  ;:  weld
    %+  expect-eq
      !>  3
      !>  (lent result)
    %+  expect-eq
      !>  ~2024.1.15
      !>  -:(snag 0 result)
    %+  expect-eq
      !>  ~2024.2.15
      !>  -:(snag 1 result)
    %+  expect-eq
      !>  ~2024.3.15
      !>  -:(snag 2 result)
  ==
::  test exdates
::
++  test-exdates
  =/  rule=recurrence-rule:calendar
    [%daily 1 ~ ~ ~ ~ ~ ~ 0 (sy ~[~2024.1.3])]
  =/  start=@da  ~2024.1.1
  =/  end=@da    ~2024.1.1..01.00.00
  =/  result=(list [@da @da])
    (expand:rrule rule start end ~2024.1.1 ~2024.1.5)
  %+  expect-eq
    !>  3
    !>  (lent result)
--
