{ Builder } = require '../Builder'
fs = require 'fs'
path = require 'path'
util = require 'util'

# Used as a fallback for the webserver. Instantiated directly from the server
# middleware. This Builder will always build a textual response explaining why a
# particular resource is a 404.
module.exports = class Fallback extends Builder
  handleRequest: (req, res, next) ->
    accept = req.headers.accept ? ""

    reasons = @enumerateProblems @target.name

    res.statusCode = 404

    if ~accept.indexOf 'html'
      data = @renderHTML reasons
      res.setHeader 'Content-Type', 'text/html; charset=utf-8'
      res.write data
      res.end()

    else if ~accept.indexOf 'json'
      data = JSON.stringify
        error:
          message: "Unable to build #{@target.name}\n\n#{reasons.join "\n"}"
      res.setHeader 'Content-Type', 'application/json'
      res.write data
      res.end()

    else
      data = "Unable to build #{@target.name}\n\nReasons:\n" +
        ("    #{r}\n" for r in reasons).join ''
      res.setHeader 'Content-Type', 'text/plain; charset=utf-8'
      res.write data
      res.end()

  enumerateProblems: (path) ->
    # Hijack options to get more verbosity
    [ old_log, old_verbosity ] = [ console.log, @manager.getOption 'verbose' ]
    reasons = []
    try
      # Do the resolution with high verbosity and logging
      console.log = (args...) ->
        reasons.push util.format args...
      @manager.setOption 'verbose', 9
      @manager.resolve @target
    finally
      # Restore the old information
      console.log = old_log
      @manager.setOption 'verbose', old_verbosity

    reasons

  renderHTML: (reasons) ->
    title = "404 - File not found"
    extra = ""
    if @target.name == 'index.html'
      needed_file = path.join @manager.getSourcePath(), @target.name
      title = "Welcome to webapp!"
      extra = "<h2>Create the file #{needed_file} to get started.</h2>"

    """
    <!DOCTYPE html>
    <html>
    <head>
    <title>#{title}</title>
    <style type="text/css">
    body {
      background: #ece9e9;
      color: #555;
      margin: 0;
      padding: 80px 100px;
      font: 13px "Helvetica Neue", "Lucida Grande", "Arial";
      -webkit-font-smoothing: antialiased;
    }
    h1 {
      color: #343434;
    }
    </style>
    </head>
    <body>
    <h1>#{title}</h1>
    #{extra}
    <p>
      The file #{@target.name} could not be built. The following information may be relevant:
    </p>
    <ul>
      #{("<li><tt>#{r}</tt></li>\n" for r in reasons).join ''}
    </ul>
    </body>
    </html>
    """
