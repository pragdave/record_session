Start a new terminal session and record all the output activity, along with
the corresponding timestamps, to a log file. By default, the file
named `terminal.record`, but can be overridden using the -o option.

The output file is structured as a JSON object.

```
  session = {
    size: [86, 25],
    data: [
      [32,"ZSHRC\r\n"]
      [33,"\u001bAnSiTu dave\r\n\u001bAnSiTc /Users/dave/Play/ttyrec\r\n"]
      [283,"\u001b[1m\u001b[7m%\u001b[27m\u001b[1m\u001b[m"], ...
```

The first entry is the size of the window of the captured session.

This is followed by a list of the data that was written to the terminal.
The first entry is the time in milliseconds since the previous event.
The second is the data written, JSON escaped.

Copyright (c) 2014 Dave Thomas, The Pragmatic Programmers

See LICENSE.txt for the license (hint: it's MIT)
