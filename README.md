⛔️ DEPRECATED - webapp-builder
===============================

Webapp Builder was what I built when webpack was very young. Webpack is no longer very young, and is in fact now very good. Use that instead.

Webapp Builder handles the static assets for you node.js application. For a brief video describing a basic use case for a static website, check out [this screencast]. Out of the box, webapp supports:

 - Automatically reload client-side files on modification: HTML, CSS, JavaScript, even images.
 - CommonJS modules (packaged using [modulr]).
 - Compilation of [CoffeeScript] to JavaScipt and [LessCSS] to CSS.
 - Automatically restart the server-side processes on modification.

[this screencast]: https://vimeo.com/68808324
[CoffeeScript]: http://coffeescript.org/
[LessCSS]: http://lesscss.org/
[modulr]: https://github.com/tobie/modulr-node

Simple server
-------------

    npm install -g webapp-builder
    webapp serve

This will start a web server on a random port and begin serving the current directory. On Mac OS X, it will open a brower window to the local URL. As you create and edit files, the browser window will automatically refresh.

Use with express apps
---------------------
Webapp Builder can be used as a drop-in replacement for `express.static`.

```javascript
var express = require('express');
var webapp = require('webapp-builder');
var app = express();
var server = app.listen(8080);
app.use(webapp({
  sourcePath: __dirname + "/public",
  autoRefreshUsingServer: server,
  fallthrough: false
}));
console.log("Listening at http://localhost:8080/");
```

When used like this, webapp will serve the files under `public/`, automatically refreshing them as they are changed; and uses `express.static` under the hood to ensure that built products are properly cached. As an additional benefit, you can take advantage of server-side refreshing as well:

    webapp monitor app.js

Now every time a file required by app.js gets modified, webapp will automatically restart the server process.

License
-------
The MIT License (MIT)

Copyright (c) 2013 Ryan Patterson

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
