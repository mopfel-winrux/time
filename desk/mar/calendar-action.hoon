/-  calendar
|_  act=action:calendar
++  grow
  |%
  ++  noun  act
  --
++  grab
  |%
  ++  noun  action:calendar
  ++  json
    |=  jon=json
    ^-  action:calendar
    =,  dejs:format
    =/  typ=@t  ((ot ~[action+so]) jon)
    ?+  typ  !!
        %'create-calendar'
      =/  f  (ot ~[name+so color+(se %ux) description+so])
      =/  [n=@t c=@ux d=@t]  (f jon)
      [%create-calendar n c d]
    ::
        %'update-calendar'
      =/  f  (ot ~[calendar-id+(se %uv) name+so color+(se %ux) description+so])
      =/  [cid=@uv n=@t c=@ux d=@t]  (f jon)
      [%update-calendar cid n c d]
    ::
        %'delete-calendar'
      [%delete-calendar ((ot ~[calendar-id+(se %uv)]) jon)]
    ::
        %'reorder-calendars'
      =/  order=(list calendar-id:calendar)
        ((ot ~[order+(ar (se %uv))]) jon)
      [%reorder-calendars order]
    ::
        %'create-event'
      [%create-event (parse-event jon)]
    ::
        %'update-event'
      =/  eid=@uv  ((ot ~[event-id+(se %uv)]) jon)
      [%update-event eid (parse-event jon)]
    ::
        %'delete-event'
      [%delete-event ((ot ~[event-id+(se %uv)]) jon)]
    ::
        %'move-event'
      =/  f  (ot ~[event-id+(se %uv) start+ni end+ni])
      =/  [eid=@uv s=@ud e=@ud]  (f jon)
      [%move-event eid (from-unix s) (from-unix e)]
    ::
        %'create-booking-type'
      [%create-booking-type (parse-booking-type jon)]
    ::
        %'update-booking-type'
      =/  btid=@uv  ((ot ~[booking-type-id+(se %uv)]) jon)
      [%update-booking-type btid (parse-booking-type jon)]
    ::
        %'delete-booking-type'
      [%delete-booking-type ((ot ~[booking-type-id+(se %uv)]) jon)]
    ::
        %'set-availability'
      =/  rules=(list availability-rule:calendar)
        %+  turn
        ((ot ~[rules+(ar (ot ~[day+ni start+ni end+ni]))]) jon)
        |=  [d=@ud s=@ud e=@ud]
        ^-  availability-rule:calendar
        [d s e]
      [%set-availability rules]
    ::
        %'toggle-booking-page'
      [%toggle-booking-page ~]
    ::
        %'update-booking-page'
      =/  f  (ot ~[title+so description+so])
      =/  [t=@t d=@t]  (f jon)
      [%update-booking-page t d]
    ::
        %'book-slot'
      =/  f  (ot ~[booking-type-id+(se %uv) booker-name+so booker-email+so start+ni notes+so])
      =/  [btid=@uv bn=@t be=@t s=@ud n=@t]  (f jon)
      [%book-slot btid bn be ~ (from-unix s) n]
    ::
        %'cancel-booking'
      [%cancel-booking ((ot ~[booking-id+(se %uv)]) jon)]
    ::
        %'confirm-booking'
      [%confirm-booking ((ot ~[booking-id+(se %uv)]) jon)]
    ::
        %'update-settings'
      =/  f  (ot ~[default-timezone+so week-start-day+ni default-view+so])
      =/  [tz=@t wsd=@ud dv=@t]  (f jon)
      =/  dc=(unit @uv)
        =/  raw  ((ot ~[default-calendar+(mu (se %uv))]) jon)
        raw
      [%update-settings [tz wsd dv dc]]
    ::
        %'import-ical'
      =/  f  (ot ~[cal-name+so ics-data+so])
      =/  [cn=@t icd=@t]  (f jon)
      [%import-ical cn icd]
    ::
        %'subscribe-calendar'
      =/  f  (ot ~[url+so cal-name+so refresh-minutes+ni])
      =/  [u=@t cn=@t rm=@ud]  (f jon)
      [%subscribe-calendar u cn (mul ~m1 rm)]
    ::
        %'unsubscribe-calendar'
      [%unsubscribe-calendar ((ot ~[subscription-id+(se %uv)]) jon)]
    ::
        %'refresh-subscription'
      [%refresh-subscription ((ot ~[subscription-id+(se %uv)]) jon)]
    ==
  ::
  ++  parse-event
    |=  jon=json
    ^-  event:calendar
    =,  dejs:format
    =/  f
      %~  ot  by
      :~  title+so
          description+so
          calendar-id+(se %uv)
          start+ni
          end+ni
          location+so
          all-day+bo
      ==
    =/  [t=@t d=@t cid=@uv s=@ud e=@ud l=@t ad=?]
      (f jon)
    =/  reminders=(list reminder:calendar)
      =/  raw  ((ot ~[reminders+(ar (ot ~[minutes-before+ni]))]) jon)
      (turn raw |=(mb=@ud [mb]))
    =/  rrule=(unit recurrence-rule:calendar)
      =/  has-rrule=?
        ?~  jon  |
        ?.  ?=(%o -.jon)  |
        (~(has by p.jon) 'rrule')
      ?.  has-rrule  ~
      =/  rr-json=json  (~(got by p.jon) 'rrule')
      ?:  =(~ rr-json)  ~
      `(parse-rrule-json rr-json)
    :*  t
        d
        cid
        (from-unix s)
        (from-unix e)
        l
        ad
        rrule
        reminders
        ''
        *@da
        *@da
    ==
  ::
  ++  parse-rrule-json
    |=  jon=json
    ^-  recurrence-rule:calendar
    =,  dejs:format
    =/  freq-str=@t  ((ot ~[freq+so]) jon)
    =/  freq=frequency:calendar
      ?+  freq-str  %daily
        %daily    %daily
        %weekly   %weekly
        %monthly  %monthly
        %yearly   %yearly
      ==
    =/  interval=@ud
      (fall ((ot ~[interval+(mu ni)]) jon) 1)
    :*  freq
        interval
        ~
        ~
        ~
        ~
        ~
        ~
        1
        ~
    ==
  ::
  ++  parse-booking-type
    |=  jon=json
    ^-  booking-type:calendar
    =,  dejs:format
    =/  f
      (ot ~[name+so duration+ni description+so color+(se %ux) calendar-id+(se %uv) buffer-time+ni active+bo])
    =/  [n=@t dur=@ud d=@t c=@ux cid=@uv bt=@ud a=?]
      (f jon)
    [n dur d c cid bt a]
  ::
  ++  from-unix
    |=  u=@ud
    ^-  @da
    (add ~1970.1.1 (mul ~s1 u))
  --
++  grad  %noun
--
