::  time: calendar and scheduling agent for urbit
::
::    manages calendars, events, booking types, availability,
::    and serves a JSON API via eyre including public booking endpoints.
::    supports publishing public calendars to %contacts peers.
::
/-  calendar, calendar-state
/+  dbug, verb, server, default-agent, ical, rrule
|%
+$  card  card:agent:gall
::  +parse-ud: parse plain decimal digits (no dots required)
::
++  parse-ud
  |=  t=@t
  ^-  (unit @ud)
  (rush t (bass 10 (plus sid:ab)))
::  +assign-event-ids: stamp parsed events with calendar-id, timestamps, unique ids
::
++  assign-event-ids
  |=  [evts=(list event:calendar) cid=calendar-id:calendar now=@da eny=@uvJ]
  ^-  (map event-id:calendar event:calendar)
  =/  acc=(map event-id:calendar event:calendar)  ~
  |-
  ?~  evts  acc
  =/  ev=event:calendar  i.evts
  =.  calendar-id.ev  cid
  =.  created.ev  now
  =.  modified.ev  now
  =/  eid=event-id:calendar
    ?:  =('' uid.ev)
      (sham (mix title.ev eny))
    (sham (mix (sham uid.ev) start.ev))
  =.  uid.ev  ?:(=('' uid.ev) (scot %uv eid) uid.ev)
  $(evts t.evts, acc (~(put by acc) eid ev))
::  +is-contact: check if a ship is in our %contacts directory
::
++  is-contact
  |=  [our=@p now=@da her=ship]
  ^-  ?
  =/  result=(unit ?)
    %-  mole
    |.
    =/  dir  .^((map ^ship *) %gx /(scot %p our)/contacts/(scot %da now)/v1/all/contact-directory-0)
    (~(has by dir) her)
  (fall result %.n)
::  +get-contact-display-name: resolve ship to pet name, nickname, or @p
::
++  get-contact-display-name
  |=  [our=@p now=@da her=ship]
  ^-  @t
  =/  result=(unit @t)
    %-  mole
    |.
    =/  dir
      .^((map ^ship (map @tas *)) %gx /(scot %p our)/contacts/(scot %da now)/v1/all/contact-directory-0)
    =/  entry=(unit (map @tas *))  (~(get by dir) her)
    ?~  entry  (scot %p her)
    =/  nick=(unit *)  (~(get by u.entry) %nickname)
    ?~  nick  (scot %p her)
    =/  nick-text=@t  ;;(@t u.nick)
    ?:  =('' nick-text)  (scot %p her)
    nick-text
  (fall result (scot %p her))
--
::
%-  agent:dbug
=|  state-1:calendar
=*  state  -
%+  verb  |
^-  agent:gall
|_  =bowl:gall
+*  this   .
    def    ~(. (default-agent this %|) bowl)
::
++  on-leave  on-leave:def
++  on-fail   on-fail:def
::
++  on-save
  ^-  vase
  !>(state)
::
++  on-load
  |=  =vase
  ^-  (quip card _this)
  =/  old  !<(versioned-state:calendar-state vase)
  ?-  -.old
    %1  `this(state old)
  ::
    %0
  ::  migrate calendars: add public=%.n to each
  =/  new-cals=(map calendar-id:calendar calendar:calendar)
    %-  ~(run by calendars.old)
    |=  old-cal=calendar-0:calendar
    ^-  calendar:calendar
    [name.old-cal color.old-cal description.old-cal %.n]
  :-  ~
  %=  this
    state  :*  %1
               new-cals
               calendar-order.old
               events.old
               booking-types.old
               availability-rules.old
               bookings.old
               subscriptions.old
               booking-page.old
               settings.old
               *(map contact-calendar-id:calendar contact-calendar:calendar)
           ==
  ==
  ==
::
++  on-init
  ^-  (quip card _this)
  =/  default-settings=settings:calendar
    ['UTC' 0 'month' ~]
  =/  default-page=booking-page:calendar
    [| 'Book a Meeting' 'Schedule time with me']
  ::  create a default calendar so users can start creating events immediately
  =/  cid=calendar-id:calendar  (sham (mix 'My Calendar' eny.bowl))
  =/  cal=calendar:calendar  ['My Calendar' 0x39.8be2 '' %.n]
  :_  %=  this
        settings       default-settings
        booking-page   default-page
        calendars      (~(put by *(map calendar-id:calendar calendar:calendar)) cid cal)
        calendar-order  ~[cid]
      ==
  :~  ::  authenticated API
      :*  %pass  /eyre/connect
          %arvo  %e  %connect
          [`/apps/time/api dap.bowl]
      ==
      ::  public booking API
      :*  %pass  /eyre/public
          %arvo  %e  %connect
          [`/apps/time/api/public dap.bowl]
      ==
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  |^
  ?+  mark
    (on-poke:def mark vase)
  ::
      %calendar-action
    =/  act=action:calendar  !<(action:calendar vase)
    (handle-action act)
  ::
      %handle-http-request
    (handle-http !<([@ta inbound-request:eyre] vase))
  ==
  ::
  ++  handle-action
    |=  act=action:calendar
    ^-  (quip card _this)
    ?>  =(src our):bowl
    ?-  -.act
    ::
        %create-calendar
      =/  cid=calendar-id:calendar  (sham (mix name.act eny.bowl))
      =/  cal=calendar:calendar  [name.act color.act description.act %.n]
      =/  upd=update:calendar  [%calendar-added cid cal]
      :_  %=  this
            calendars  (~(put by calendars) cid cal)
            calendar-order  (snoc calendar-order cid)
          ==
      :~  [%give %fact ~[/updates] calendar-update+!>(upd)]
      ==
    ::
        %update-calendar
      =/  cid  calendar-id.act
      ?.  (~(has by calendars) cid)  `this
      =/  old-cal=calendar:calendar  (~(got by calendars) cid)
      =/  cal=calendar:calendar  [name.act color.act description.act public.old-cal]
      =/  upd=update:calendar  [%calendar-updated cid cal]
      =/  cards=(list card)
        :~  [%give %fact ~[/updates] calendar-update+!>(upd)]
        ==
      ::  if calendar is public, notify subscribers of name/color change
      =?  cards  public.old-cal
        %+  snoc  cards
        [%give %fact ~[/public/(scot %uv cid)] public-calendar-update+!>([%calendar-updated cal])]
      :_  this(calendars (~(put by calendars) cid cal))
      cards
    ::
        %delete-calendar
      =/  cid  calendar-id.act
      ?.  (~(has by calendars) cid)  `this
      =/  cal=calendar:calendar  (~(got by calendars) cid)
      ::  remove all events belonging to this calendar
      =/  evts-to-del=(list event-id:calendar)
        %+  murn  ~(tap by events)
        |=  [eid=event-id:calendar ev=event:calendar]
        ?.(=(calendar-id.ev cid) ~ `eid)
      =/  new-events=(map event-id:calendar event:calendar)  events
      =/  del-list=(list event-id:calendar)  evts-to-del
      |-
      ?~  del-list
        =/  upd=update:calendar  [%calendar-removed cid]
        =/  cards=(list card)
          :~  [%give %fact ~[/updates] calendar-update+!>(upd)]
          ==
        ::  if calendar was public, notify and kick subscribers
        =?  cards  public.cal
          %+  welp  cards
          :~  [%give %fact ~[/public/(scot %uv cid)] public-calendar-update+!>([%calendar-removed ~])]
              [%give %kick ~[/public/(scot %uv cid)] ~]
          ==
        :_  %=  this
              calendars  (~(del by calendars) cid)
              calendar-order  (skip calendar-order |=(c=calendar-id:calendar =(c cid)))
              events  new-events
            ==
        cards
      %=  $
        new-events  (~(del by new-events) i.del-list)
        del-list    t.del-list
      ==
    ::
        %reorder-calendars
      `this(calendar-order order.act)
    ::
        %create-event
      =/  ev=event:calendar  event.act
      =/  eid=event-id:calendar  (sham (mix title.ev eny.bowl))
      =.  uid.ev  ?:(=('' uid.ev) (scot %uv eid) uid.ev)
      =.  created.ev  now.bowl
      =.  modified.ev  now.bowl
      =/  upd=update:calendar  [%event-added eid ev]
      =/  cards=(list card)
        :~  [%give %fact ~[/updates] calendar-update+!>(upd)]
        ==
      ::  if calendar is public, notify subscribers
      =/  cal=(unit calendar:calendar)  (~(get by calendars) calendar-id.ev)
      =?  cards  ?&(?=(^ cal) public.u.cal)
        %+  snoc  cards
        [%give %fact ~[/public/(scot %uv calendar-id.ev)] public-calendar-update+!>([%event-added eid ev])]
      :_  this(events (~(put by events) eid ev))
      cards
    ::
        %update-event
      =/  eid  event-id.act
      ?.  (~(has by events) eid)  `this
      =/  ev=event:calendar  event.act
      =.  modified.ev  now.bowl
      =/  old=event:calendar  (~(got by events) eid)
      =.  uid.ev  ?:(=('' uid.ev) uid.old uid.ev)
      =.  created.ev  ?:(=(*@da created.ev) created.old created.ev)
      =/  upd=update:calendar  [%event-updated eid ev]
      =/  cards=(list card)
        :~  [%give %fact ~[/updates] calendar-update+!>(upd)]
        ==
      =/  cal=(unit calendar:calendar)  (~(get by calendars) calendar-id.ev)
      =?  cards  ?&(?=(^ cal) public.u.cal)
        %+  snoc  cards
        [%give %fact ~[/public/(scot %uv calendar-id.ev)] public-calendar-update+!>([%event-updated eid ev])]
      :_  this(events (~(put by events) eid ev))
      cards
    ::
        %delete-event
      =/  eid  event-id.act
      ?.  (~(has by events) eid)  `this
      =/  ev=event:calendar  (~(got by events) eid)
      =/  upd=update:calendar  [%event-removed eid]
      =/  cards=(list card)
        :~  [%give %fact ~[/updates] calendar-update+!>(upd)]
        ==
      =/  cal=(unit calendar:calendar)  (~(get by calendars) calendar-id.ev)
      =?  cards  ?&(?=(^ cal) public.u.cal)
        %+  snoc  cards
        [%give %fact ~[/public/(scot %uv calendar-id.ev)] public-calendar-update+!>([%event-removed eid])]
      :_  this(events (~(del by events) eid))
      cards
    ::
        %move-event
      =/  eid  event-id.act
      =/  ev=(unit event:calendar)  (~(get by events) eid)
      ?~  ev  `this
      =/  new-ev=event:calendar  u.ev(start start.act, end end.act, modified now.bowl)
      =/  upd=update:calendar  [%event-updated eid new-ev]
      =/  cards=(list card)
        :~  [%give %fact ~[/updates] calendar-update+!>(upd)]
        ==
      =/  cal=(unit calendar:calendar)  (~(get by calendars) calendar-id.u.ev)
      =?  cards  ?&(?=(^ cal) public.u.cal)
        %+  snoc  cards
        [%give %fact ~[/public/(scot %uv calendar-id.u.ev)] public-calendar-update+!>([%event-updated eid new-ev])]
      :_  this(events (~(put by events) eid new-ev))
      cards
    ::
        %create-booking-type
      =/  btid=booking-type-id:calendar  (sham (mix name.booking-type.act eny.bowl))
      =/  upd=update:calendar  [%settings-updated settings]
      :_  this(booking-types (~(put by booking-types) btid booking-type.act))
      ~
    ::
        %update-booking-type
      =/  btid  booking-type-id.act
      ?.  (~(has by booking-types) btid)  `this
      `this(booking-types (~(put by booking-types) btid booking-type.act))
    ::
        %delete-booking-type
      =/  btid  booking-type-id.act
      `this(booking-types (~(del by booking-types) btid))
    ::
        %set-availability
      `this(availability-rules rules.act)
    ::
        %toggle-booking-page
      `this(booking-page booking-page(enabled !enabled.booking-page))
    ::
        %update-booking-page
      `this(booking-page booking-page(title title.act, description description.act))
    ::
        %book-slot
      =/  btid  booking-type-id.act
      =/  bt=(unit booking-type:calendar)  (~(get by booking-types) btid)
      ?~  bt  `this
      ::  create an event for this booking
      =/  eid=event-id:calendar  (sham (mix booker-name.act eny.bowl))
      =/  ev-end=@da  (add start.act (mul ~m1 duration.u.bt))
      =/  ev=event:calendar
        :*  (crip "Booking: {(trip booker-name.act)}")
            notes.act
            calendar-id.u.bt
            start.act
            ev-end
            ''
            |
            ~
            ~
            (scot %uv eid)
            now.bowl
            now.bowl
        ==
      =/  bid=booking-id:calendar  (sham (mix start.act eny.bowl))
      =/  bk=booking:calendar
        [btid eid booker-name.act booker-email.act booker-ship.act start.act notes.act %confirmed now.bowl]
      =/  upd-ev=update:calendar  [%event-added eid ev]
      =/  upd-bk=update:calendar  [%booking-created bid bk]
      :_  %=  this
            events    (~(put by events) eid ev)
            bookings  (~(put by bookings) bid bk)
          ==
      :~  [%give %fact ~[/updates] calendar-update+!>(upd-ev)]
          [%give %fact ~[/updates] calendar-update+!>(upd-bk)]
      ==
    ::
        %cancel-booking
      =/  bid  booking-id.act
      =/  bk=(unit booking:calendar)  (~(get by bookings) bid)
      ?~  bk  `this
      =/  new-bk=booking:calendar  u.bk(status %cancelled)
      =/  upd=update:calendar  [%booking-cancelled bid]
      :_  this(bookings (~(put by bookings) bid new-bk))
      :~  [%give %fact ~[/updates] calendar-update+!>(upd)]
      ==
    ::
        %confirm-booking
      =/  bid  booking-id.act
      =/  bk=(unit booking:calendar)  (~(get by bookings) bid)
      ?~  bk  `this
      =/  new-bk=booking:calendar  u.bk(status %confirmed)
      =/  upd=update:calendar  [%booking-confirmed bid]
      :_  this(bookings (~(put by bookings) bid new-bk))
      :~  [%give %fact ~[/updates] calendar-update+!>(upd)]
      ==
    ::
        %update-settings
      =/  upd=update:calendar  [%settings-updated settings.act]
      :_  this(settings settings.act)
      :~  [%give %fact ~[/updates] calendar-update+!>(upd)]
      ==
    ::
        %import-ical
      =/  [evts=(list event:calendar) cal-meta=(unit [name=@t description=@t])]
        (parse-ical:ical ics-data.act)
      ::  create or find a calendar for the import
      =/  cal-name=@t
        ?:  !=('' cal-name.act)  cal-name.act
        ?~  cal-meta  'Imported Calendar'
        name.u.cal-meta
      =/  cid=calendar-id:calendar  (sham (mix cal-name eny.bowl))
      =/  cal=calendar:calendar
        =/  desc=@t
          ?~  cal-meta  ''
          description.u.cal-meta
        [cal-name 0x39.8be2 desc %.n]
      =/  cards=(list card)  ~
      =/  new-events=(map event-id:calendar event:calendar)  events
      =/  new-calendars=(map calendar-id:calendar calendar:calendar)  calendars
      =/  new-order=(list calendar-id:calendar)  calendar-order
      ::  add the calendar if it doesn't exist
      =?  new-calendars  !(~(has by new-calendars) cid)
        (~(put by new-calendars) cid cal)
      =?  new-order  !(~(has by new-calendars) cid)
        (snoc new-order cid)
      ::  add all events
      =/  imported  (assign-event-ids evts cid now.bowl eny.bowl)
      =/  new-events  (~(uni by new-events) imported)
      :_  %=  this
            calendars       new-calendars
            calendar-order  new-order
            events          new-events
          ==
      cards
    ::
        %export-ical
      ::  handled in GET endpoint, no-op as action
      `this
    ::
        %subscribe-calendar
      =/  cid=calendar-id:calendar  (sham (mix url.act eny.bowl))
      =/  cal=calendar:calendar  [cal-name.act 0x42.85f4 '' %.n]
      =/  sid=subscription-id:calendar  (sham (mix cid eny.bowl))
      =/  sub=calendar-subscription:calendar
        [url.act cid refresh-interval.act *@da ~]
      =/  upd=update:calendar
        [%subscription-added sid sub]
      :_  %=  this
            calendars      (~(put by calendars) cid cal)
            calendar-order  (snoc calendar-order cid)
            subscriptions  (~(put by subscriptions) sid sub)
          ==
      =/  nex=@da  (add now.bowl refresh-interval.act)
      :~  [%give %fact ~[/updates] calendar-update+!>(upd)]
          [%pass /sub-fetch/(scot %uv sid) %arvo %i %request [%'GET' url.act ~ ~] redirects=5 retries=3]
          [%pass /sub-timer/(scot %uv sid) %arvo %b %wait nex]
      ==
    ::
        %unsubscribe-calendar
      =/  sid  subscription-id.act
      =/  sub=(unit calendar-subscription:calendar)  (~(get by subscriptions) sid)
      ?~  sub  `this
      =/  upd=update:calendar  [%subscription-removed sid]
      =/  cancel-time=@da  (add last-fetched.u.sub refresh-interval.u.sub)
      :_  %=  this
            subscriptions  (~(del by subscriptions) sid)
          ==
      :~  [%give %fact ~[/updates] calendar-update+!>(upd)]
          [%pass /sub-timer/(scot %uv sid) %arvo %b %rest cancel-time]
      ==
    ::
        %refresh-subscription
      =/  sid  subscription-id.act
      =/  sub=(unit calendar-subscription:calendar)  (~(get by subscriptions) sid)
      ?~  sub  `this
      :_  this
      :~  [%pass /sub-fetch/(scot %uv sid) %arvo %i %request [%'GET' url.u.sub ~ ~] redirects=5 retries=3]
      ==
    ::
    ::  contacts integration actions
    ::
        %toggle-public
      =/  cid  calendar-id.act
      =/  cal=(unit calendar:calendar)  (~(get by calendars) cid)
      ?~  cal  `this
      =/  new-pub=?  !public.u.cal
      =/  new-cal=calendar:calendar  u.cal(public new-pub)
      =/  upd=update:calendar  [%calendar-publicity-changed cid new-pub]
      =/  cards=(list card)
        :~  [%give %fact ~[/updates] calendar-update+!>(upd)]
        ==
      ::  if going private, kick all subscribers on /public/[cid]
      =?  cards  !new-pub
        %+  snoc  cards
        [%give %kick ~[/public/(scot %uv cid)] ~]
      :_  this(calendars (~(put by calendars) cid new-cal))
      cards
    ::
        %subscribe-contact-calendar
      =/  ccid=contact-calendar-id:calendar
        (sham (mix (mix ship.act calendar-id.act) eny.bowl))
      =/  cc=contact-calendar:calendar
        [ship.act calendar-id.act ['?' 0x88.8888 '' %.y] ~ %.y now.bowl]
      =/  upd=update:calendar  [%contact-calendar-added ccid cc]
      :_  this(contact-calendars (~(put by contact-calendars) ccid cc))
      :~  [%pass /contact-cal/(scot %uv ccid) %agent [ship.act %time] %watch /public/(scot %uv calendar-id.act)]
          [%give %fact ~[/updates] calendar-update+!>(upd)]
      ==
    ::
        %unsubscribe-contact-calendar
      =/  ccid  contact-calendar-id.act
      =/  cc=(unit contact-calendar:calendar)  (~(get by contact-calendars) ccid)
      ?~  cc  `this
      =/  upd=update:calendar  [%contact-calendar-removed ccid]
      :_  this(contact-calendars (~(del by contact-calendars) ccid))
      :~  [%pass /contact-cal/(scot %uv ccid) %agent [ship.u.cc %time] %leave ~]
          [%give %fact ~[/updates] calendar-update+!>(upd)]
      ==
    ::
        %toggle-contact-calendar
      =/  ccid  contact-calendar-id.act
      =/  cc=(unit contact-calendar:calendar)  (~(get by contact-calendars) ccid)
      ?~  cc  `this
      =/  new-cc=contact-calendar:calendar  u.cc(enabled !enabled.u.cc)
      =/  upd=update:calendar  [%contact-calendar-toggled ccid enabled.new-cc]
      :_  this(contact-calendars (~(put by contact-calendars) ccid new-cc))
      :~  [%give %fact ~[/updates] calendar-update+!>(upd)]
      ==
    ::
        %discover-contact-calendars
      :_  this
      :~  [%pass /discover/(scot %p ship.act) %agent [ship.act %time] %watch /public-list]
      ==
    ==
  ::
  ::  HTTP request handling
  ::
  ++  handle-http
    |=  [eyre-id=@ta req=inbound-request:eyre]
    ^-  (quip card _this)
    =/  rl=request-line:server
      (parse-request-line:server url.request.req)
    =/  site=(list @t)  site.rl
    ::  check if this is a public API request
    =/  is-public=?
      ?=([%apps %time %api %public *] site)
    ::  strip prefix
    =/  api-path=(list @t)
      ?:  is-public
        ?:  ?=([%apps %time %api %public *] site)
          t.t.t.t.site
        site
      ?.  ?=([%apps %time %api *] site)
        site
      t.t.t.site
    ::  re-attach extension to last segment (IDs with dots)
    =/  api-path=(list @t)
      ?~  ext.rl  api-path
      ?~  api-path  api-path
      %+  snoc
        (scag (dec (lent api-path)) `(list @t)`api-path)
      (crip "{(trip (rear api-path))}.{(trip u.ext.rl)}")
    ::  public endpoints don't require auth
    ?.  ?|(is-public authenticated.req)
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      (login-redirect:gen:server request.req)
    ?+  method.request.req
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      [[405 ~] ~]
    ::
        %'GET'
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      ?:  is-public
        (handle-public-scry api-path)
      (handle-scry api-path rl)
    ::
        %'POST'
      ?:  is-public
        (handle-public-poke eyre-id req)
      (handle-poke eyre-id req)
    ==
  ::
  ++  handle-scry
    |=  [site=(list @t) rl=request-line:server]
    ^-  simple-payload:http
    ?+  site
      not-found:gen:server
    ::
        [%calendars ~]
      =/  ordered-cals=(list [calendar-id:calendar calendar:calendar])
        ?~  calendar-order  ~(tap by calendars)
        =/  in-order=(list [calendar-id:calendar calendar:calendar])
          %+  murn  calendar-order
          |=  cid=calendar-id:calendar
          =/  cal=(unit calendar:calendar)  (~(get by calendars) cid)
          ?~  cal  ~
          `[cid u.cal]
        =/  order-set=(set calendar-id:calendar)
          (~(gas in *(set calendar-id:calendar)) calendar-order)
        =/  rest=(list [calendar-id:calendar calendar:calendar])
          (skip ~(tap by calendars) |=([cid=calendar-id:calendar *] (~(has in order-set) cid)))
        (welp in-order rest)
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  :-  'calendars'
          :-  %a
          %+  turn  ordered-cals
          |=  [cid=calendar-id:calendar cal=calendar:calendar]
          =/  ev-count=@ud
            %+  roll  ~(tap by events)
            |=  [[eid=event-id:calendar ev=event:calendar] count=@ud]
            ?.(=(calendar-id.ev cid) count +(count))
          %-  pairs:enjs:format
          :~  ['id' s+(scot %uv cid)]
              ['name' s+name.cal]
              ['color' s+(scot %ux color.cal)]
              ['description' s+description.cal]
              ['public' b+public.cal]
              ['event-count' (numb:enjs:format ev-count)]
          ==
      ==
    ::
        [%calendar @ ~]
      =/  cid=(unit calendar-id:calendar)  (slaw %uv i.t.site)
      ?~  cid  not-found:gen:server
      =/  cal=(unit calendar:calendar)  (~(get by calendars) u.cid)
      ?~  cal  not-found:gen:server
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  ['id' s+(scot %uv u.cid)]
          ['name' s+name.u.cal]
          ['color' s+(scot %ux color.u.cal)]
          ['description' s+description.u.cal]
          ['public' b+public.u.cal]
      ==
    ::
        [%events ~]
      ::  parse start/end/cal query params
      =/  args=(list [key=@t value=@t])  args.rl
      =/  range-start=(unit @da)
        =/  v  (get-arg args 'start')
        ?~  v  ~
        =/  n  (parse-ud u.v)
        ?~  n  ~
        `(add ~1970.1.1 (mul ~s1 u.n))
      =/  range-end=(unit @da)
        =/  v  (get-arg args 'end')
        ?~  v  ~
        =/  n  (parse-ud u.v)
        ?~  n  ~
        `(add ~1970.1.1 (mul ~s1 u.n))
      =/  cal-filter=(unit calendar-id:calendar)
        =/  v  (get-arg args 'cal')
        ?~  v  ~
        (slaw %uv u.v)
      =/  rs=@da  (fall range-start (sub now.bowl ~d30))
      =/  re=@da  (fall range-end (add now.bowl ~d30))
      =/  all-evts=(list [event-id:calendar event:calendar])  ~(tap by events)
      ::  filter by calendar if specified
      =?  all-evts  ?=(^ cal-filter)
        (skim all-evts |=([* ev=event:calendar] =(calendar-id.ev u.cal-filter)))
      ::  collect non-recurring events in range + expand recurring
      =/  result=(list [event-id:calendar event:calendar])
        %-  zing
        %+  turn  all-evts
        |=  [eid=event-id:calendar ev=event:calendar]
        ^-  (list [event-id:calendar event:calendar])
        ?~  rrule.ev
          ::  non-recurring: check overlap
          ?:  ?&((lth start.ev re) (gth end.ev rs))
            ~[[eid ev]]
          ~
        ::  recurring: expand
        =/  occurrences=(list [@da @da])
          (expand:rrule u.rrule.ev start.ev end.ev rs re)
        %+  turn  occurrences
        |=  [os=@da oe=@da]
        [eid ev(start os, end oe)]
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  :-  'events'
          :-  %a
          %+  turn  result
          |=  [eid=event-id:calendar ev=event:calendar]
          %-  pairs:enjs:format
          :~  ['id' s+(scot %uv eid)]
              ['title' s+title.ev]
              ['description' s+description.ev]
              ['calendar-id' s+(scot %uv calendar-id.ev)]
              ['start' (sect:enjs:format start.ev)]
              ['end' (sect:enjs:format end.ev)]
              ['location' s+location.ev]
              ['all-day' b+all-day.ev]
              ['has-rrule' b+?=(^ rrule.ev)]
              ['uid' s+uid.ev]
              :-  'reminders'
              :-  %a
              %+  turn  reminders.ev
              |=  r=reminder:calendar
              (pairs:enjs:format ~[['minutes-before' (numb:enjs:format minutes-before.r)]])
          ==
      ==
    ::
        [%event @ ~]
      =/  eid=(unit event-id:calendar)  (slaw %uv i.t.site)
      ?~  eid  not-found:gen:server
      =/  ev=(unit event:calendar)  (~(get by events) u.eid)
      =/  is-contact=?  %.n
      ::  if not found locally, search contact calendar events
      =?  is-contact  ?=(~ ev)  %.y
      =?  ev  ?=(~ ev)
        =/  cc-list=(list [contact-calendar-id:calendar contact-calendar:calendar])
          ~(tap by contact-calendars)
        |-
        ?~  cc-list  ~
        =/  cev=(unit event:calendar)  (~(get by events.+.i.cc-list) u.eid)
        ?^  cev  cev
        $(cc-list t.cc-list)
      ?~  ev  not-found:gen:server
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  ['id' s+(scot %uv u.eid)]
          ['title' s+title.u.ev]
          ['description' s+description.u.ev]
          ['calendar-id' s+(scot %uv calendar-id.u.ev)]
          ['start' (sect:enjs:format start.u.ev)]
          ['end' (sect:enjs:format end.u.ev)]
          ['location' s+location.u.ev]
          ['all-day' b+all-day.u.ev]
          ['uid' s+uid.u.ev]
          ['created' (sect:enjs:format created.u.ev)]
          ['modified' (sect:enjs:format modified.u.ev)]
          ['read-only' b+is-contact]
          :-  'reminders'
          :-  %a
          %+  turn  reminders.u.ev
          |=  r=reminder:calendar
          (pairs:enjs:format ~[['minutes-before' (numb:enjs:format minutes-before.r)]])
      ==
    ::
        [%'booking-types' ~]
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  :-  'booking-types'
          :-  %a
          %+  turn  ~(tap by booking-types)
          |=  [btid=booking-type-id:calendar bt=booking-type:calendar]
          %-  pairs:enjs:format
          :~  ['id' s+(scot %uv btid)]
              ['name' s+name.bt]
              ['duration' (numb:enjs:format duration.bt)]
              ['description' s+description.bt]
              ['color' s+(scot %ux color.bt)]
              ['calendar-id' s+(scot %uv calendar-id.bt)]
              ['buffer-time' (numb:enjs:format buffer-time.bt)]
              ['active' b+active.bt]
              ['conflict-calendars' [%a (turn conflict-calendars.bt |=(c=calendar-id:calendar s+(scot %uv c)))]]
          ==
      ==
    ::
        [%availability ~]
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  :-  'rules'
          :-  %a
          %+  turn  availability-rules
          |=  ar=availability-rule:calendar
          %-  pairs:enjs:format
          :~  ['day' (numb:enjs:format day.ar)]
              ['start' (numb:enjs:format start.ar)]
              ['end' (numb:enjs:format end.ar)]
          ==
      ==
    ::
        [%bookings ~]
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  :-  'bookings'
          :-  %a
          %+  turn  ~(tap by bookings)
          |=  [bid=booking-id:calendar bk=booking:calendar]
          %-  pairs:enjs:format
          :~  ['id' s+(scot %uv bid)]
              ['booking-type-id' s+(scot %uv booking-type-id.bk)]
              ['event-id' s+(scot %uv event-id.bk)]
              ['booker-name' s+booker-name.bk]
              ['booker-email' s+booker-email.bk]
              ['start' (sect:enjs:format start.bk)]
              ['notes' s+notes.bk]
              ['status' s+status.bk]
              ['created' (sect:enjs:format created.bk)]
          ==
      ==
    ::
        [%settings ~]
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  ['default-timezone' s+default-timezone.settings]
          ['week-start-day' (numb:enjs:format week-start-day.settings)]
          ['default-view' s+default-view.settings]
          :-  'default-calendar'
          ?~  default-calendar.settings  ~
          s+(scot %uv u.default-calendar.settings)
      ==
    ::
        [%'booking-page' ~]
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  ['enabled' b+enabled.booking-page]
          ['title' s+title.booking-page]
          ['description' s+description.booking-page]
      ==
    ::
        [%'subscriptions' ~]
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  :-  'subscriptions'
          :-  %a
          %+  turn  ~(tap by subscriptions)
          |=  [sid=subscription-id:calendar sub=calendar-subscription:calendar]
          %-  pairs:enjs:format
          :~  ['id' s+(scot %uv sid)]
              ['url' s+url.sub]
              ['calendar-id' s+(scot %uv calendar-id.sub)]
              ['refresh-interval' (numb:enjs:format (div refresh-interval.sub ~m1))]
              ['last-fetched' (sect:enjs:format last-fetched.sub)]
              ['error' ?~(error.sub ~ s+u.error.sub)]
          ==
      ==
    ::
        [%'contact-calendars' ~]
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  :-  'contact-calendars'
          :-  %a
          %+  turn  ~(tap by contact-calendars)
          |=  [ccid=contact-calendar-id:calendar cc=contact-calendar:calendar]
          %-  pairs:enjs:format
          :~  ['id' s+(scot %uv ccid)]
              ['ship' s+(scot %p ship.cc)]
              ['display-name' s+(get-contact-display-name our.bowl now.bowl ship.cc)]
              ['calendar-id' s+(scot %uv calendar-id.cc)]
              ['name' s+name.calendar.cc]
              ['color' s+(scot %ux color.calendar.cc)]
              ['description' s+description.calendar.cc]
              ['enabled' b+enabled.cc]
              ['last-updated' (sect:enjs:format last-updated.cc)]
              :-  'events'
              :-  %a
              %+  turn  ~(tap by events.cc)
              |=  [eid=event-id:calendar ev=event:calendar]
              %-  pairs:enjs:format
              :~  ['id' s+(scot %uv eid)]
                  ['title' s+title.ev]
                  ['description' s+description.ev]
                  ['calendar-id' s+(scot %uv calendar-id.ev)]
                  ['start' (sect:enjs:format start.ev)]
                  ['end' (sect:enjs:format end.ev)]
                  ['location' s+location.ev]
                  ['all-day' b+all-day.ev]
                  ['has-rrule' b+?=(^ rrule.ev)]
                  ['uid' s+uid.ev]
              ==
          ==
      ==
    ::
        [%contacts ~]
      =/  peers=(unit (map ship *))
        %-  mole
        |.
        .^((map ship *) %gx /(scot %p our.bowl)/contacts/(scot %da now.bowl)/v1/all/contact-directory-0)
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  :-  'contacts'
          :-  %a
          ?~  peers  ~
          %+  turn  ~(tap by u.peers)
          |=  [s=ship *]
          %-  pairs:enjs:format
          :~  ['ship' s+(scot %p s)]
              ['display-name' s+(get-contact-display-name our.bowl now.bowl s)]
          ==
      ==
    ::
        [%'export-ical' @ ~]
      =/  cid=(unit calendar-id:calendar)  (slaw %uv i.t.site)
      ?~  cid  not-found:gen:server
      =/  cal=(unit calendar:calendar)  (~(get by calendars) u.cid)
      ?~  cal  not-found:gen:server
      =/  cal-events=(list event:calendar)
        %+  murn  ~(tap by events)
        |=  [eid=event-id:calendar ev=event:calendar]
        ?.(=(calendar-id.ev u.cid) ~ `ev)
      =/  ics=@t  (generate-ical:ical u.cal cal-events)
      :_  `(as-octs:mimes:html ics)
      [200 ['content-type' 'text/calendar'] ['content-disposition' 'attachment; filename="calendar.ics"'] ~]
    ::
        [%'export-ical' ~]
      ::  export all calendars
      =/  all-events=(list event:calendar)
        (turn ~(tap by events) |=([* ev=event:calendar] ev))
      =/  cal=calendar:calendar  ['All Calendars' 0x0 '' %.n]
      =/  ics=@t  (generate-ical:ical cal all-events)
      :_  `(as-octs:mimes:html ics)
      [200 ['content-type' 'text/calendar'] ['content-disposition' 'attachment; filename="calendar.ics"'] ~]
    ==
  ::
  ++  handle-public-scry
    |=  site=(list @t)
    ^-  simple-payload:http
    ?+  site
      not-found:gen:server
    ::
        [%'booking-types' ~]
      ?.  enabled.booking-page
        %-  json-response:gen:server
        (pairs:enjs:format ~[['booking-types' [%a ~]]])
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  :-  'booking-types'
          :-  %a
          %+  murn  ~(tap by booking-types)
          |=  [btid=booking-type-id:calendar bt=booking-type:calendar]
          ?.  active.bt  ~
          :-  ~
          %-  pairs:enjs:format
          :~  ['id' s+(scot %uv btid)]
              ['name' s+name.bt]
              ['duration' (numb:enjs:format duration.bt)]
              ['description' s+description.bt]
              ['color' s+(scot %ux color.bt)]
          ==
      ==
    ::
        [%'available-slots' @ @ ~]
      ?.  enabled.booking-page
        %-  json-response:gen:server
        (pairs:enjs:format ~[['slots' [%a ~]]])
      =/  bt-id=(unit @uv)  (slaw %uv i.t.site)
      =/  date-unix=(unit @ud)  (parse-ud i.t.t.site)
      ?~  bt-id
        %-  json-response:gen:server
        (pairs:enjs:format ~[['error' s+'missing type parameter']])
      ?~  date-unix
        %-  json-response:gen:server
        (pairs:enjs:format ~[['error' s+'missing date parameter']])
      =/  bt=(unit booking-type:calendar)  (~(get by booking-types) u.bt-id)
      ?~  bt
        %-  json-response:gen:server
        (pairs:enjs:format ~[['error' s+'booking type not found']])
      =/  target-date=@da  (add ~1970.1.1 (mul ~s1 u.date-unix))
      =/  slots=(list @da)  (compute-slots u.bt target-date)
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  :-  'slots'
          :-  %a
          %+  turn  slots
          |=  s=@da
          (sect:enjs:format s)
      ==
    ::
        [%info ~]
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  ['enabled' b+enabled.booking-page]
          ['title' s+title.booking-page]
          ['description' s+description.booking-page]
          ['ship' s+(scot %p our.bowl)]
      ==
    ==
  ::
  ::
  ++  compute-slots
    |=  [bt=booking-type:calendar target-date=@da]
    ^-  (list @da)
    ::  get day-of-week: ~2000.1.1 is Saturday (6)
    =/  days-since=@ud  (div (sub target-date (sub target-date (mod target-date ~d1))) ~d1)
    =/  target-start=@da  (sub target-date (mod target-date ~d1))
    =/  epoch-days=@ud  (div (sub target-start ~2000.1.1) ~d1)
    =/  dow=@ud  (mod (add epoch-days 6) 7)
    ::  find matching availability rules for this day
    =/  effective-rules=(list availability-rule:calendar)
      ?~  availability-rules
        ^-  (list availability-rule:calendar)
        :~  [1 540 1.020]  [2 540 1.020]  [3 540 1.020]  [4 540 1.020]  [5 540 1.020]
        ==
      availability-rules
    =/  day-rules=(list availability-rule:calendar)
      (skim effective-rules |=(ar=availability-rule:calendar =(day.ar dow)))
    ?~  day-rules  ~
    ::  get existing events on the target calendar for this date
    =/  day-start=@da  target-start
    =/  day-end=@da  (add target-start ~d1)
    =/  check-all=?  =(~ conflict-calendars.bt)
    =/  cc=(set calendar-id:calendar)  (silt conflict-calendars.bt)
    =/  existing=(list [start=@da end=@da])
      %+  murn  ~(tap by events)
      |=  [eid=event-id:calendar ev=event:calendar]
      ?.  ?|(check-all (~(has in cc) calendar-id.ev))  ~
      ?.  ?&((lth start.ev day-end) (gth end.ev day-start))  ~
      ?~  rrule.ev
        `[start.ev end.ev]
      ::  expand recurring events for this day
      ~
    ::  also include expanded recurring events
    =/  recurring-occs=(list [start=@da end=@da])
      %-  zing
      %+  murn  ~(tap by events)
      |=  [eid=event-id:calendar ev=event:calendar]
      ?.  ?|(check-all (~(has in cc) calendar-id.ev))  ~
      ?~  rrule.ev  ~
      `(expand:rrule u.rrule.ev start.ev end.ev day-start day-end)
    =/  all-existing=(list [start=@da end=@da])
      (welp existing recurring-occs)
    ::  generate candidate slots from availability windows
    =/  slot-dur=@dr  (mul ~m1 duration.bt)
    =/  slot-step=@dr  (mul ~m1 (add duration.bt buffer-time.bt))
    =/  candidates=(list @da)
      %-  zing
      %+  turn  day-rules
      |=  ar=availability-rule:calendar
      ^-  (list @da)
      =/  window-start=@da  (add target-start (mul ~m1 start.ar))
      =/  window-end=@da    (add target-start (mul ~m1 end.ar))
      =|  slots=(list @da)
      =/  cur=@da  window-start
      |-
      ?:  (gte (add cur slot-dur) window-end)  (flop slots)
      $(slots [cur slots], cur (add cur slot-step))
    ::  filter out candidates that overlap existing events
    %+  skim  candidates
    |=  slot-start=@da
    =/  slot-end=@da  (add slot-start slot-dur)
    ::  filter out past slots
    ?.  (gth slot-start now.bowl)  |
    ::  check no overlap with existing events
    %+  levy  all-existing
    |=  [es=@da ee=@da]
    ?|  (gte slot-start ee)
        (lte slot-end es)
    ==
  ::
  ++  handle-poke
    |=  [eyre-id=@ta req=inbound-request:eyre]
    ^-  (quip card _this)
    =/  body=(unit octs)  body.request.req
    ?~  body
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      [[400 ~] ~]
    =/  jon=(unit json)  (de:json:html q.u.body)
    ?~  jon
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      [[400 ~] ~]
    =/  act=(unit action:calendar)
      %-  mole
      |.((json:grab:calendar-action-mark u.jon))
    ?~  act
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      [[400 ~] `(as-octs:mimes:html 'invalid action')]
    =/  [cards=(list card) new-this=_this]
      (handle-action u.act)
    :_  new-this
    %+  welp
      %+  give-simple-payload:app:server  eyre-id
      %-  json-response:gen:server
      (pairs:enjs:format ~[['ok' b+%.y]])
    cards
  ::
  ++  handle-public-poke
    |=  [eyre-id=@ta req=inbound-request:eyre]
    ^-  (quip card _this)
    =/  body=(unit octs)  body.request.req
    ?~  body
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      [[400 ~] ~]
    =/  jon=(unit json)  (de:json:html q.u.body)
    ?~  jon
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      [[400 ~] ~]
    ?.  enabled.booking-page
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      [[403 ~] `(as-octs:mimes:html 'booking page not enabled')]
    =,  dejs:format
    =/  parsed=(unit [btid=@uv bn=@t be=@t s=@ud n=@t])
      %-  mole
      |.
      =/  f  (ot ~[booking-type-id+(se %uv) booker-name+so booker-email+so start+ni notes+so])
      (f u.jon)
    ?~  parsed
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      [[400 ~] `(as-octs:mimes:html 'invalid booking request')]
    =/  btid=@uv  btid.u.parsed
    =/  bt=(unit booking-type:calendar)  (~(get by booking-types) btid)
    ?~  bt
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      [[404 ~] `(as-octs:mimes:html 'booking type not found')]
    =/  start=@da  (add ~1970.1.1 (mul ~s1 s.u.parsed))
    =/  eid=event-id:calendar  (sham (mix bn.u.parsed eny.bowl))
    =/  ev-end=@da  (add start (mul ~m1 duration.u.bt))
    =/  ev=event:calendar
      :*  (crip "Booking: {(trip bn.u.parsed)}")
          n.u.parsed
          calendar-id.u.bt
          start
          ev-end
          ''
          |
          ~
          ~
          (scot %uv eid)
          now.bowl
          now.bowl
      ==
    =/  bid=booking-id:calendar  (sham (mix start eny.bowl))
    =/  bk=booking:calendar
      [btid eid bn.u.parsed be.u.parsed ~ start n.u.parsed %confirmed now.bowl]
    :_  %=  this
          events    (~(put by events) eid ev)
          bookings  (~(put by bookings) bid bk)
        ==
    %+  give-simple-payload:app:server  eyre-id
    %-  json-response:gen:server
    (pairs:enjs:format ~[['ok' b+%.y] ['message' s+'booking confirmed']])
  ::
  ++  calendar-action-mark
    |_  act=action:calendar
    ++  grab
      |%
      ++  json
        |=  jon=^json
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
          [%create-event (parse-event-json jon)]
        ::
            %'update-event'
          =/  eid=@uv  ((ot ~[event-id+(se %uv)]) jon)
          [%update-event eid (parse-event-json jon)]
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
          [%create-booking-type (parse-bt-json jon)]
        ::
            %'update-booking-type'
          =/  btid=@uv  ((ot ~[booking-type-id+(se %uv)]) jon)
          [%update-booking-type btid (parse-bt-json jon)]
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
          [%update-settings [tz wsd dv ~]]
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
        ::
            %'toggle-public'
          [%toggle-public ((ot ~[calendar-id+(se %uv)]) jon)]
        ::
            %'subscribe-contact-calendar'
          =/  f  (ot ~[ship+(se %p) calendar-id+(se %uv)])
          =/  [s=@p cid=@uv]  (f jon)
          [%subscribe-contact-calendar s cid]
        ::
            %'unsubscribe-contact-calendar'
          [%unsubscribe-contact-calendar ((ot ~[contact-calendar-id+(se %uv)]) jon)]
        ::
            %'toggle-contact-calendar'
          [%toggle-contact-calendar ((ot ~[contact-calendar-id+(se %uv)]) jon)]
        ::
            %'discover-contact-calendars'
          [%discover-contact-calendars ((ot ~[ship+(se %p)]) jon)]
        ==
      --
    --
  ::
  ++  parse-event-json
    |=  jon=json
    ^-  event:calendar
    =,  dejs:format
    =/  f
      (ot ~[title+so description+so calendar-id+(se %uv) start+ni end+ni location+so all-day+bo])
    =/  [t=@t d=@t cid=@uv s=@ud e=@ud l=@t ad=?]
      (f jon)
    =/  reminders=(list reminder:calendar)
      =/  raw  ((ot ~[reminders+(ar (ot ~[minutes-before+ni]))]) jon)
      (turn raw |=(mb=@ud `reminder:calendar`[mb]))
    :*  t
        d
        cid
        (from-unix s)
        (from-unix e)
        l
        ad
        ~
        reminders
        ''
        *@da
        *@da
    ==
  ::
  ++  parse-bt-json
    |=  jon=json
    ^-  booking-type:calendar
    =,  dejs:format
    =/  f
      (ot ~[name+so duration+ni description+so color+(se %ux) calendar-id+(se %uv) buffer-time+ni active+bo])
    =/  [n=@t dur=@ud d=@t c=@ux cid=@uv bt=@ud a=?]
      (f jon)
    =/  ccs=(list calendar-id:calendar)
      =/  cc-json=(unit json)  (~(get by p:?>(?=(%o -.jon) jon)) 'conflict-calendars')
      ?~  cc-json  ~
      ((ar (se %uv)) u.cc-json)
    [n dur d c cid bt a ccs]
  ::
  ++  from-unix
    |=  u=@ud
    ^-  @da
    (add ~1970.1.1 (mul ~s1 u))
  ::
  ++  get-arg
    |=  [args=(list [key=@t value=@t]) key=@t]
    ^-  (unit @t)
    =/  match  (skim args |=([k=@t *] =(k key)))
    ?~  match  ~
    `value.i.match
  --
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:def path)
    [%updates ~]          `this
    [%http-response @ ~]  `this
  ::
      [%public @ ~]
    ::  remote ship subscribes to one of our public calendars
    =/  cid=(unit calendar-id:calendar)  (slaw %uv i.t.path)
    ?~  cid  (on-watch:def path)
    =/  cal=(unit calendar:calendar)  (~(get by calendars) u.cid)
    ?~  cal  (on-watch:def path)
    ?.  public.u.cal
      ~|(%calendar-not-public !!)
    ?.  (is-contact our.bowl now.bowl src.bowl)
      ~|(%not-a-contact !!)
    ::  send initial full snapshot
    =/  cal-events=(map event-id:calendar event:calendar)
      %-  ~(rep by events)
      |=  [[eid=event-id:calendar ev=event:calendar] acc=(map event-id:calendar event:calendar)]
      ?.  =(calendar-id.ev u.cid)  acc
      (~(put by acc) eid ev)
    =/  init=public-calendar-update:calendar
      [%full u.cal cal-events]
    :_  this
    :~  [%give %fact ~ public-calendar-update+!>(init)]
    ==
  ::
      [%public-list ~]
    ::  remote ship discovers our public calendars (one-shot)
    ?.  (is-contact our.bowl now.bowl src.bowl)
      ~|(%not-a-contact !!)
    =/  pub-cals=(list [calendar-id:calendar calendar:calendar])
      %+  skim  ~(tap by calendars)
      |=  [cid=calendar-id:calendar cal=calendar:calendar]
      public.cal
    =/  cal-list=json
      :-  %a
      %+  turn  pub-cals
      |=  [cid=calendar-id:calendar cal=calendar:calendar]
      %-  pairs:enjs:format
      :~  ['calendar-id' s+(scot %uv cid)]
          ['name' s+name.cal]
          ['color' s+(scot %ux color.cal)]
          ['description' s+description.cal]
      ==
    :_  this
    :~  [%give %fact ~ json+!>(cal-list)]
        [%give %kick ~ ~]
    ==
  ==
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?+  wire  (on-agent:def wire sign)
  ::
      [%contact-cal @ ~]
    =/  ccid=@uv  (slav %uv i.t.wire)
    =/  cc=(unit contact-calendar:calendar)  (~(get by contact-calendars) ccid)
    ?~  cc  `this
    ?+  -.sign  (on-agent:def wire sign)
    ::
        %fact
      ?.  =(%public-calendar-update p.cage.sign)  `this
      =/  upd=public-calendar-update:calendar
        !<(public-calendar-update:calendar q.cage.sign)
      ?-  -.upd
          %full
        =/  new-cc=contact-calendar:calendar
          u.cc(calendar calendar.upd, events events.upd, last-updated now.bowl)
        =/  local-upd=update:calendar
          [%contact-calendar-updated ccid new-cc]
        :_  this(contact-calendars (~(put by contact-calendars) ccid new-cc))
        :~  [%give %fact ~[/updates] calendar-update+!>(local-upd)]
        ==
      ::
          %event-added
        =/  new-evts  (~(put by events.u.cc) event-id.upd event.upd)
        =/  new-cc=contact-calendar:calendar
          u.cc(events new-evts, last-updated now.bowl)
        :_  this(contact-calendars (~(put by contact-calendars) ccid new-cc))
        :~  [%give %fact ~[/updates] calendar-update+!>([%contact-calendar-updated ccid new-cc])]
        ==
      ::
          %event-updated
        =/  new-evts  (~(put by events.u.cc) event-id.upd event.upd)
        =/  new-cc=contact-calendar:calendar
          u.cc(events new-evts, last-updated now.bowl)
        :_  this(contact-calendars (~(put by contact-calendars) ccid new-cc))
        :~  [%give %fact ~[/updates] calendar-update+!>([%contact-calendar-updated ccid new-cc])]
        ==
      ::
          %event-removed
        =/  new-evts  (~(del by events.u.cc) event-id.upd)
        =/  new-cc=contact-calendar:calendar
          u.cc(events new-evts, last-updated now.bowl)
        :_  this(contact-calendars (~(put by contact-calendars) ccid new-cc))
        :~  [%give %fact ~[/updates] calendar-update+!>([%contact-calendar-updated ccid new-cc])]
        ==
      ::
          %calendar-updated
        =/  new-cc=contact-calendar:calendar
          u.cc(calendar calendar.upd, last-updated now.bowl)
        :_  this(contact-calendars (~(put by contact-calendars) ccid new-cc))
        :~  [%give %fact ~[/updates] calendar-update+!>([%contact-calendar-updated ccid new-cc])]
        ==
      ::
          %calendar-removed
        =/  local-upd=update:calendar  [%contact-calendar-removed ccid]
        :_  this(contact-calendars (~(del by contact-calendars) ccid))
        :~  [%give %fact ~[/updates] calendar-update+!>(local-upd)]
        ==
      ==
    ::
        %kick
      ::  re-subscribe on kick (standard reconnection pattern)
      =/  watch-path=path  /public/(scot %uv calendar-id.u.cc)
      :_  this
      :~  [%pass /contact-cal/(scot %uv ccid) %agent [ship.u.cc %time] %watch watch-path]
      ==
    ::
        %watch-ack
      ?~  p.sign  `this
      ::  subscription rejected
      ~&  [%time %contact-cal-rejected ccid u.p.sign]
      `this
    ==
  ::
      [%discover @ ~]
    =/  her=@p  (slav %p i.t.wire)
    ?+  -.sign  (on-agent:def wire sign)
    ::
        %fact
      ?.  =(%json p.cage.sign)  `this
      =/  jon=json  !<(json q.cage.sign)
      ?.  ?=(%a -.jon)  `this
      =/  cal-list=(list [calendar-id:calendar calendar:calendar])
        %+  murn  p.jon
        |=  item=json
        ^-  (unit [calendar-id:calendar calendar:calendar])
        =/  result=(unit [calendar-id:calendar calendar:calendar])
          %-  mole
          |.
          =,  dejs:format
          =/  f  (ot ~[calendar-id+(se %uv) name+so color+(se %ux) description+so])
          =/  [cid=@uv n=@t c=@ux d=@t]  (f item)
          [cid [n c d %.y]]
        result
      ::  check which calendars we already have subscribed
      =/  existing=(set [ship calendar-id:calendar])
        %-  ~(rep by contact-calendars)
        |=  [[k=contact-calendar-id:calendar v=contact-calendar:calendar] acc=(set [ship calendar-id:calendar])]
        (~(put in acc) [ship.v calendar-id.v])
      ::  auto-subscribe to new calendars (disabled by default)
      =/  new-cals=(list [calendar-id:calendar calendar:calendar])
        %+  skip  cal-list
        |=  [cid=calendar-id:calendar cal=calendar:calendar]
        (~(has in existing) [her cid])
      =/  cards=(list card)  ~
      =/  new-ccs=(map contact-calendar-id:calendar contact-calendar:calendar)  contact-calendars
      |-
      ?~  new-cals
        :_  this(contact-calendars new-ccs)
        cards
      =/  cid=calendar-id:calendar  -.i.new-cals
      =/  cal=calendar:calendar  +.i.new-cals
      =/  ccid=contact-calendar-id:calendar
        (sham (mix (mix her cid) eny.bowl))
      =/  cc=contact-calendar:calendar
        [her cid cal ~ %.n now.bowl]
      =/  upd=update:calendar  [%contact-calendar-added ccid cc]
      %=  $
        new-cals  t.new-cals
        new-ccs   (~(put by new-ccs) ccid cc)
        cards
          :+  [%pass /contact-cal/(scot %uv ccid) %agent [her %time] %watch /public/(scot %uv cid)]
            [%give %fact ~[/updates] calendar-update+!>(upd)]
          cards
      ==
    ::
        %kick  `this
        %watch-ack  `this
    ==
  ==
::
++  on-arvo
  |=  [=wire sign=sign-arvo]
  ^-  (quip card _this)
  ?+  wire  (on-arvo:def wire sign)
      [%eyre *]
    ?>  ?=(%bound +<.sign)
    ~?  !accepted.sign  [dap.bowl %binding-rejected binding.sign]
    `this
  ::
      [%sub-fetch @ ~]
    =/  sid=@uv  (slav %uv i.t.wire)
    =/  sub=(unit calendar-subscription:calendar)  (~(get by subscriptions) sid)
    ?~  sub  `this
    ?>  ?=(%iris -.sign)
    ?>  ?=(%http-response +<.sign)
    =/  =client-response:iris  +>.sign
    ?.  ?=(%finished -.client-response)  `this
    ?~  full-file.client-response
      =/  new-sub  u.sub(error `'fetch failed: no response body', last-fetched now.bowl)
      =/  upd=update:calendar  [%subscription-refreshed sid now.bowl `'fetch failed']
      :_  this(subscriptions (~(put by subscriptions) sid new-sub))
      :~  [%give %fact ~[/updates] calendar-update+!>(upd)]
      ==
    ?.  =(200 status-code.response-header.client-response)
      =/  new-sub  u.sub(error `'fetch failed: bad status', last-fetched now.bowl)
      =/  upd=update:calendar  [%subscription-refreshed sid now.bowl `'bad status']
      :_  this(subscriptions (~(put by subscriptions) sid new-sub))
      :~  [%give %fact ~[/updates] calendar-update+!>(upd)]
      ==
    =/  ics-data=@t  q.data.u.full-file.client-response
    =/  [evts=(list event:calendar) cal-meta=(unit [name=@t description=@t])]
      (parse-ical:ical ics-data)
    =/  cid  calendar-id.u.sub
    ::  remove old events for this calendar, then add new ones
    =/  new-events=(map event-id:calendar event:calendar)
      %-  ~(rep by events)
      |=  [[eid=event-id:calendar ev=event:calendar] acc=(map event-id:calendar event:calendar)]
      ?.  =(calendar-id.ev cid)  (~(put by acc) eid ev)
      acc
    ::  add parsed events
    =/  imported  (assign-event-ids evts cid now.bowl eny.bowl)
    =/  new-sub  u.sub(last-fetched now.bowl, error ~)
    =/  upd=update:calendar  [%subscription-refreshed sid now.bowl ~]
    :_  %=  this
          events         (~(uni by new-events) imported)
          subscriptions  (~(put by subscriptions) sid new-sub)
        ==
    :~  [%give %fact ~[/updates] calendar-update+!>(upd)]
    ==
  ::
      [%sub-timer @ ~]
    =/  sid=@uv  (slav %uv i.t.wire)
    =/  sub=(unit calendar-subscription:calendar)  (~(get by subscriptions) sid)
    ?~  sub  `this
    ?>  ?=(%behn -.sign)
    ::  re-fetch and set next timer
    =/  nex=@da  (add now.bowl refresh-interval.u.sub)
    :_  this
    :~  [%pass /sub-fetch/(scot %uv sid) %arvo %i %request [%'GET' url.u.sub ~ ~] redirects=5 retries=3]
        [%pass /sub-timer/(scot %uv sid) %arvo %b %wait nex]
    ==
  ==
::
++  on-peek
  |=  =(pole knot)
  ^-  (unit (unit cage))
  ?+  pole  (on-peek:def `path`pole)
    [%x %calendars ~]
      =/  =json
        %-  pairs:enjs:format
        :~  :-  'calendars'
            :-  %a
            %+  turn  ~(tap by calendars)
            |=  [cid=calendar-id:calendar cal=calendar:calendar]
            %-  pairs:enjs:format
            :~  ['id' s+(scot %uv cid)]
                ['name' s+name.cal]
                ['color' s+(scot %ux color.cal)]
                ['public' b+public.cal]
            ==
        ==
      ``json+!>(json)
  ==
--
