::  time-fileserver: generic from-clay file-serving agent
::
::    for copying into desks as a standalone %deskname-fileserver agent.
::
::    ** in general, you should not need to modify this file directly. **
::    instead this agent will read configuration parameters from a
::    /app/fileserver/config.hoon. this file must produce a core
::    with at least a +web-root arm. all other overrides for the
::    default configuration (see below) are optional.
::
/+  dbug
/=  config  /app/fileserver/config
::
|%
::  required config parameters:
::
::  +web-root: url under which your files will be served
::
++  web-root   ^-  (list @t)  web-root:config
::
::  optional config parameters, with default:
::
::  +file-root: path on this desk under which the files to serve live
::
++  file-root  ^-  path  file-root:config
--
::
|%
+$  state-0
  $:  %0
      foot=path
      woot=path
      cash=(set @t)
  ==
::
+$  card  card:agent:gall
::
++  store  ::  set cache entry
  |=  [url=@t entry=(unit cache-entry:eyre)]
  ^-  card
  [%pass /eyre/cache %arvo %e %set-response url entry]
::
++  read-next
  |=  [[our=@p =desk now=@da] foot=path]
  ^-  card
  =;  =task:clay
    [%pass [%clay %next foot] %arvo %c task]
  [%warp our desk ~ %next %z da+now foot]
::
++  set-norm
  |=  [[our=@p =desk] foot=path keep=?]
  ^-  card
  =;  =task:clay
    [%pass [%clay %norm foot] %arvo %c task]
  [%tomb %norm our desk (~(put of *norm:clay) foot keep)]
--
::
=|  state-0
=*  state  -
::
%-  agent:dbug
^-  agent:gall
|_  =bowl:gall
+*  this  .
::
++  on-init
  ^-  (quip card _this)
  =.  foot  file-root
  =.  woot  web-root
  :_  this
  :~  [%pass /eyre/connect %arvo %e %connect [~ woot] dap.bowl]
      (set-norm [our q.byk]:bowl foot |)
      (read-next [our q.byk now]:bowl foot)
  ==
::
++  on-save
  ^-  vase
  !>(state)
::
++  on-load
  |=  ole=vase
  ^-  (quip card _this)
  =/  old  !<(state-0 ole)
  :_  this(foot file-root, woot web-root, cash ~)
  %-  zing
  ^-  (list (list card))
  :~  ?:  =(foot.old file-root)  ~
      [(set-norm [our q.byk]:bowl file-root |)]~
    ::
      :-  (read-next [our q.byk now]:bowl file-root)
      :-  [%pass /clay/tomb %arvo %c %tomb %pick ~]
      (turn ~(tap in cash.old) (curr store ~))
    ::
      ?:  =(foot.old file-root)  ~
      [(set-norm [our q.byk]:bowl foot.old &)]~
    ::
      ^-  (list card)
      ?:  =(woot.old web-root)  ~
      :~  [%pass /eyre/connect %arvo %e %connect [~ woot.old] dap.bowl]
          [%pass /eyre/connect %arvo %e %disconnect [~ woot.old]]
          [%pass /eyre/connect %arvo %e %connect [~ web-root] dap.bowl]
      ==
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ~|  mark=mark
  ?>  ?=(%handle-http-request mark)
  =+  !<([rid=@ta inbound-request:eyre] vase)
  =;  [sav=? pay=simple-payload:http]
    =/  serve=(list card)
      =/  =path  /http-response/[rid]
      :~  [%give %fact ~[path] [%http-response-header !>(response-header.pay)]]
          [%give %fact ~[path] [%http-response-data !>(data.pay)]]
          [%give %kick ~[path] ~]
      ==
    ?.  sav  [serve this]
    :_  this(cash (~(put in cash) url.request))
    %+  snoc  serve
    (store url.request ~ auth=| %payload pay)
  ::  allow static assets without auth for public booking page
  ::  the SPA shell (html/js/css) contains no user data;
  ::  all private data is gated by the API auth layer in %time
  ::
  =/  public-paths=(set @t)
    %-  ~(gas in *(set @t))
    :~  '/apps/time'
        '/apps/time/'
        '/apps/time/index.html'
        '/apps/time/js/api.js'
        '/apps/time/js/app.js'
        '/apps/time/js/booking.js'
        '/apps/time/css/app.css'
        '/apps/time/manifest.json'
        '/apps/time/fonts/inter-light.woff2'
        '/apps/time/fonts/inter-regular.woff2'
        '/apps/time/fonts/inter-medium.woff2'
        '/apps/time/fonts/inter-semibold.woff2'
    ==
  ?.  ?|  authenticated
          (~(has in public-paths) url.request)
      ==
    [| [403 ~] `(as-octs:mimes:html 'unauthenticated')]
  ?.  ?=(%'GET' method.request)
    [| [405 ~] `(as-octs:mimes:html 'read-only resource')]
  =+  ^-  [[ext=(unit @ta) site=(list @t)] args=(list [key=@t value=@t])]
    =-  (fall - [[~ ~] ~])
    (rush url.request ;~(plug apat:de-purl:html yque:de-purl:html))
  ?.  =(woot (scag (lent woot) site))
    [| [500 ~] `(as-octs:mimes:html 'bad route')]
  :-  &
  ?~  ext
    ::  serve index.html for extensionless requests (SPA fallback)
    =/  idx=path
      :*  (scot %p our.bowl)
          q.byk.bowl
          (scot %da now.bowl)
          (weld foot /index/html)
      ==
    ?.  .^(? %cu idx)
      ~&  [dap.bowl %not-found-extless]
      [[404 ~] `(as-octs:mimes:html 'not found')]
    =+  .^(file=^vase %cr idx)
    =+  ~|  [%no-mime-conversion %html]
        .^(=tube:clay %cc (scot %p our.bowl) q.byk.bowl (scot %da now.bowl) /html/mime)
    =+  !<(=mime (tube file))
    :_  `q.mime
    [200 ['content-type' 'text/html'] ['cache-control' 'no-cache'] ~]
  =/  =path
    :*  (scot %p our.bowl)
        q.byk.bowl
        (scot %da now.bowl)
        (weld foot (snoc (slag (lent woot) site) u.ext))
    ==
  ?.  .^(? %cu path)
    ~&  [dap.bowl %not-found path=path]
    [[404 ~] `(as-octs:mimes:html 'not found')]
  =+  .^(file=^vase %cr path)
  =+  ~|  [%no-mime-conversion from=u.ext]
      .^(=tube:clay %cc (scot %p our.bowl) q.byk.bowl (scot %da now.bowl) /[u.ext]/mime)
  =+  !<(=mime (tube file))
  =/  content-type=@t  (rsh 3^1 (spat p.mime))
  =/  cache-val=@t
    ?+  u.ext  'max-age=3600'
      %css    'max-age=3600'
      %js     'max-age=3600'
      %svg    'max-age=86400'
      %png    'max-age=86400'
      %jpg    'max-age=86400'
      %ico    'max-age=86400'
      %woff2  'max-age=31536000, immutable'
      %html   'no-cache'
      %json   'no-cache'
    ==
  :_  `q.mime
  [200 ['content-type' content-type] ['cache-control' cache-val] ~]
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?>  ?=([%http-response @ ~] path)
  [~ this]
::
++  on-arvo
  |=  [=wire sign=sign-arvo]
  ^-  (quip card _this)
  ~|  wire=wire
  ?+  wire  !!
      [%eyre %connect ~]
    ~|  sign=+<.sign
    ?>  ?=(%bound +<.sign)
    ~?  !accepted.sign  [dap.bowl %binding-rejected binding.sign]
    [~ this]
  ::
      [%eyre %cache ~]
    ~|  sign=+<.sign
    ~|  %did-not-expect-gift
    !!
  ::
      [%clay %next *]
    ?.  =(t.t.wire foot)  [~ this]
    ~|  sign=+<.sign
    ?>  ?=(%writ +<.sign)
    :_  this(cash ~)
    :-  (read-next [our q.byk now]:bowl foot)
    (turn ~(tap in cash) (curr store ~))
  ==
::
++  on-leave  |=(* [~ this])
++  on-agent  |=(* [~ this])
++  on-peek   |=(* ~)
::
++  on-fail
  |=  [=term =tang]
  ^-  (quip card _this)
  %-  (slog (rap 3 dap.bowl ' +on-fail: ' term ~) tang)
  [~ this]
--
