express = require 'express'
BuildManager = require './BuildManager'
Node = require './Node'
Fallback = require './builders/Fallback'

exports.middleware = (args) ->
  args.runtime = 'server'
  manager = new BuildManager args

  if args.fallthrough is false
    fallback_builder = new Fallback '%%', [],
      manager: manager

  middleware = (req, res, next) ->
    request_url = req.url
    request_url += "index.html" if request_url.substr(-1) == "/"
    request_url = request_url.substring 1

    target = Node.resolve request_url, manager.getTargetPath
    builder = manager.resolve target

    if builder?
      console.log "#{req.url} will be built by #{builder}" if args.verbose > 0
    else
      if fallback_builder?
        builder = fallback_builder.getBuilderFor target
      else
        return next()

    builder.handleRequest req, res, next

exports.standalone = (args) ->
  args.fallthrough = false

  app = express.createServer()
  app.use exports.middleware args
  app.use express.errorHandler
    showStack: true

  app.listen args.port
  console.log "Server now live at http://localhost:#{app.address().port}/"
