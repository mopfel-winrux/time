::  ics mark: iCal file format
::
|_  dat=@t
++  grow
  |%
  ++  mime  [/text/calendar (as-octs:mimes:html dat)]
  ++  noun  dat
  --
++  grab
  |%
  ++  mime  |=([p=mite q=octs] (@t q.q))
  ++  noun  @t
  --
++  grad  %mime
--
