BuildManager = require './BuildManager'
{ Builder } = require './Builder'
Fallback = require './builders/Fallback'
express = require 'express'
path = require 'path'

exports.middleware = (args) ->
  manager = new BuildManager args

  if args.fallthrough is false
    fallback_builder = new Fallback '%%', [],
      manager: manager

  middleware = (req, res, next) ->
    request_url = req.url
    request_url += "index.html" if request_url.substr(-1) == "/"
    request_url = path.join manager.getOption('targetPath'),
                            request_url.substring 1

    target = manager.fs.resolve request_url
    builder = manager.resolve target

    unless builder?
      builder = Builder.createBuilderFor manager, target

    if builder?
      console.log "#{req.url} will be built by #{builder}" if args.verbose > 0

    else if args.fallthrough is false
      builder = Fallback.createBuilderFor manager, target

    else
      return next()

    builder.handleRequest req, res, next

exports.standalone = (args) ->
  args.fallthrough = false

  app = express.createServer()
  app.use exports.middleware args
  app.use express.errorHandler
    showStack: true

  server = app.listen args.port
  console.log "Server now live at http://localhost:#{server.address().port}/"
