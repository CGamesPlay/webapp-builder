webapp-builder
==============

Webapp Builder is a tool designed to make it easier to develop website with
node, particularly by managing static assets. For a brief video describing a
basic use case for a static website, check out [this screencast].

Quick start
------------

    npm install -g webapp-builder
    webapp serve

This will start a web server on a random port and begin serving the current directory. On Mac OS X, it will open a brower window to the local URL automatically.

Features
--------

The above basic usage has the following built-in features configured by default:

 - Automatic reloading for **all** files: HTML, CSS, and JavaScript files.
 - Packaging of CommonJS modules using [modulr].
 - Compilation of [CoffeeScript].
 - Cmpilation of [LessCSS].
 - Advanced custom build rules by creating a Makefile.

CLI Usage
---------

There are 3 main commands webapp:

 - `webapp serve` - Starts a static asset server in the current directory. See `webapp serve --help` for all options.
 - `webapp build` - Builds every rule specified in the Makefile. See `webapp build --help` for all options.
 - `webapp monitor COMMAND ARGS` - Loads another node module COMMAND and runs it. While it is running, if any source file referenced changes, it will kill and restart the process.

Programmatic Usage
------------------

If you ware developing a dynamic website build would like to take advantage of the automatic compilation and packaging that webapp provides, you can use it via the API.

```javascript
var express = require('express');
var http = require('http');
var webapp = require('webapp-builder');

var app = express();
var server = http.createServer(app);
var my_webapp = (new webapp.Server())
  .setFallthrough(false)
  .autoRefreshUsingServer(server);
app.use(my_webapp.middleware);

server.listen(8080);
```

[this screencast]: https://vimeo.com/68808324
[CoffeeScript]: http://coffeescript.org/
[LessCSS]: http://lesscss.org/
[modulr]: https://github.com/tobie/modulr-node
