express = require 'express'
Maker = require './Maker'
Fallback = require './builders/Fallback'

exports.middleware = (args) ->
  maker = new Maker args
  if args.file?
    maker.loadMakefile(args.file)
  else
    maker.loadDefaultMakefile()

  if args.fallthrough is false
    fallback_builder = Fallback.factory '%%', [],
      maker: maker
      implied: yes

  middleware = (req, res, next) ->
    request_url = req.url
    request_url += "index.html" if request_url.substr(-1) == "/"
    request_url = request_url.substring 1

    builder = maker.resolve request_url

    if builder?
      console.log "#{req.url} will be built by #{builder}" if args.verbose > 0
    else
      if fallback_builder?
        builder = fallback_builder.getBuilderFor request_url
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
