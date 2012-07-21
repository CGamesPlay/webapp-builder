{ Builder } = require '../Builder'
fs = require 'fs'
path = require 'path'
util = require 'util'

# Used as a fallback for the webserver. Instantiated directly from the server
# middleware. This Builder will always build a textual response explaining why a
# particular resource is a 404.
module.exports = class Fallback extends Builder
  constructor: (args...) ->
    super args...
    @isDynamicallyGenerated = yes

  getMimeType: -> "text/html"

  getData: (next) ->
    reasons = @enumerateProblems @target.name
    data = @renderHTML reasons
    next null, data

  enumerateProblems: (path) ->
    reasons = []
    listener = (level, args) ->
      reasons.push level: level, message: util.format args...
    @manager.reporter.on 'log', listener
    try
      Builder.createBuilderFor @manager, @target

    finally
      @manager.reporter.removeListener 'log', listener

    reasons

  renderHTML: (reasons) ->
    title = "404 - File not found"
    extra = ""
    if @target.getPath() == "#{@manager.getOption 'targetPath'}/index.html"
      title = "Welcome to webapp!"
      needed_file = @target.getVariantPath()
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
    li.level-0, li.level-1, li.level-2 {
      font-weight: bold;
      color: red;
    }
    </style>
    </head>
    <body>
    <h1>#{title}</h1>
    #{extra}
    <p>
      The file #{@target.getPath()} could not be built. The following information may be relevant:
    </p>
    <ul>
      #{("<li class=\"level-#{r.level}\">
            <tt>#{r.message}</tt>
          </li>\n" for r in reasons).join ''}
    </ul>
    </body>
    </html>
    """
