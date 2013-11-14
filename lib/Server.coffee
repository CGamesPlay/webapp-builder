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
    @fallthrough = args.fallthrough ? yes
    delete args.fallthrough
    @reset()
    # XXX - note that the constructor for BuildManager immediately loads the
    # makefiles, meaning that this object will be partially constructed during
    # that time.
    args.server = @
    @manager = new BuildManager args
    @staticServer = express.static path.resolve @manager.getOption 'targetPath'
    if args.autoRefreshUsingSocketIO?
      @autoRefreshUsingSocketIO args.autoRefreshUsingSocketIO
    else if args.autoRefreshUsingServer?
      @autoRefreshUsingServer args.autoRefreshUsingServer
    @postInitialize()

  # This method is called after the Makefiles have been loaded. Needed to fix up
  # the targetPath of the rules.
  postInitialize: ->
    @didPostInit = yes
    for r, i in @rules
      @rules[i].addTargetPrefix @manager.getOption 'targetPath'
    @

  reset: ->
    @rules = []
    @

  setFallthrough: (@fallthrough) ->
    @

  autoRefreshUsingSocketIO: (socketio_manager) ->
    @clientManager = new ClientManager @manager, socketio_manager
    @manager.clientManager = @clientManager
    @

  autoRefreshUsingServer: (server) ->
    @autoRefreshUsingSocketIO socketio.listen server,
      'log level': 1
    @

  addRule: (rule) ->
    unless rule instanceof Server.Rule
      rule = new Server.Rule rule
    if @didPostInit
      rule.addTargetPrefix @manager.getOption 'targetPath'
    @rules.unshift rule
    @

  generateBuilder: (target) ->
    target = @manager.fs.resolve target
    missing_files = []
    for rule in @rules when rule.matches target.getPath()
      possibility = rule.getSourcePaths target.getPath()
      nodes = for p in possibility
        @manager.fs.resolve path.join @manager.getOption('sourcePath'), p
      missing_here = (n for n in nodes when not n.exists())
      if missing_here.length == 0
        builder = new rule.builder target, nodes,
          manager: @manager
        builder.impliedSources['alternates'] = missing_files
        return builder
      else
        @manager.reporter.verbose "Builder #{rule.builder.getName()} is " +
          "missing #{(n.getPath() for n in missing_here).join(", ")}"
        missing_files = missing_files.concat nodes

    # At this point, no rules were available to build this file.
    unless @fallthrough
      builder = new Fallback target, [ ],
        manager: @manager,
        target_name: target.getPath()
      builder.impliedSources['alternates'] = missing_files
      return builder
    null

  transformURL: (url_string) ->
    url_string = url.parse(url_string).pathname
    url_string += "index.html" if url_string.substr(-1) == "/"
    url_string.substring 1

  mapURLToNode: (url_string) ->
    url_string = path.join @manager.getOption('targetPath'),
                           @transformURL url_string
    @manager.fs.resolve url_string

  middleware: (req, res, next) =>
    target = @mapURLToNode req.url

    if target.exists() and
       target.getStat().isDirectory() and
       req.url.substr(-1) != "/"
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
      builder = @generateBuilder target
      @manager.register builder if builder?

    serve_response = (err, data) =>
      if err?
        return next err unless @fallthrough is false

        res.statusCode = 500
        builder = new Fallback target, builder,
          manager: @manager
          error: err
          target_name: @transformURL req.url
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
      res.statusCode = 404
      builder.getData serve_response

    else
      next()

class Server.Rule
  constructor: (config) ->
    { @builder, @source } = config
    @source = [ @source ] unless @source instanceof Array
    @patternLength = config.target.length
    @patternParts = config.target.split '%'
    if @patternParts.length > 2
      throw new Error 'Invalid target pattern'

  addTargetPrefix: (prefix) ->
    @patternParts[0] = path.join prefix, @patternParts[0]

  matches: (path) ->
    return false unless path.length >= @patternLength
    matches_start = path.substr(0, @patternParts[0].length) is @patternParts[0]
    if @patternParts.length > 1 and @patternParts[1].length > 0
      matches_end = path.substr(-@patternParts[1].length) is @patternParts[1]
      return matches_start and matches_end
    else
      return matches_start

  wildcardPortion: (path) ->
    if @patternParts.length > 1 and @patternParts[1].length > 0
      path.substring @patternParts[0].length,
                           path.length - @patternParts[1].length
    else
      path.substring @patternParts[0].length

  getSourcePaths: (path) ->
    s.replace '%', @wildcardPortion path for s in @source
