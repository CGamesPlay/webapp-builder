BuildManager = require './BuildManager'
{ Builder } = require './Builder'
{ ClientManager } = require './ClientManager'
{ FileSystem, FileNotFoundException } = require './FileSystem'
Fallback = require './builders/Fallback'
Reporter = require './Reporter'
express = require 'express'
path = require 'path'
socketio = require 'socket.io'
url = require 'url'

module.exports = class Server
  # Deprecated. New hotness should instantiate a Server object directly, but
  # that's API-incompatible.
  @middleware_deprecated: (args) ->
    server = new Server args
    server.setFallthrough args.fallthrough if args.fallthrough?
    if args.socketIOManager?
      server.autoRefreshUsingSocketIO args.socketIOManager
    server.middleware

  constructor: (args) ->
    @manager = new BuildManager args
    @staticServer = express.static path.resolve @manager.getOption 'targetPath'

  setFallthrough: (@fallthrough) ->
    @

  autoRefreshUsingSocketIO: (socketio_manager) ->
    @clientManager = new ClientManager @manager, socketio_manager
    @manager.clientManager = @clientManager
    @

  autoRefreshUsingServer: (server) ->
    @autoRefreshUsingSocketIO socketio.listen server,
      'log level': 1

  mapURLToName: (url_string) ->
    url_string = url.parse(url_string).pathname
    url_string += "index.html" if url_string.substr(-1) == "/"
    url_string.substring 1

  mapURLToNode: (url_string) ->
    url_string = path.join @manager.getOption('targetPath'),
                           @mapURLToName url_string
    @manager.fs.resolve url_string

  middleware: (req, res, next) =>
    target = @mapURLToNode req.url

    if target.exists() and
       target.getStat().isDirectory() and
       request_url.substr(-1) != "/"
      # For directories, redirect to the trailing / form. This will cause us
      # to realize we are dealing with a directory and serve index.html
      # appropriately.
      res.redirect "#{req.url}/"
      res.end()
      return

    if req.headers.referer? and @clientManager?
      referer = @mapURLToNode req.headers.referer
      unless referer.equals target
        # Filter out refreshes
        @clientManager.addClientSideDependency referer, target

    builder = @manager.resolve target
    missing_files = []
    unless builder?
      builder = Builder.generateBuilder
        manager: @manager
        target: @mapURLToName req.url
        out_missing_files: missing_files

    serve_response = (err, data) =>
      if err?
        return next err unless @fallthrough is false

        res.statusCode = 500
        builder = new Fallback target, builder,
          manager: @manager
          error: err
          target_name: @mapURLToName req.url
        @manager.register builder
        builder.getData (err, fallback_data) -> data = fallback_data
        throw new Error "Fallback#getData isn't synchronous" unless data?

      content_type = builder.getMimeType()
      content_type += "; charset=utf-8" if content_type.indexOf('text/') is 0
      res.setHeader 'Content-Type', content_type
      res.setHeader 'Content-Length', data.length
      res.write data
      res.end()

    if builder? and not (builder instanceof Fallback)
      @manager.reporter.debug "#{req.url} will be built by #{builder}"

      # Now that the rules are definitely set up, we can use BuildManager.make.
      @manager.make target, (results) =>
        err = results[target.getPath()]
        return serve_response err if err?
        @staticServer req, res, next

    else if @fallthrough is false
      unless builder?
        builder = new Fallback target, [ ],
          manager: @manager
          target_name: @mapURLToName req.url
        builder.impliedSources['alternates'] =
          (@manager.fs.resolve f for f in missing_files)
        @manager.register builder

      res.statusCode = 404
      builder.getData serve_response

    else
      next()
