BuildManager = require './BuildManager'
{ Builder } = require './Builder'
{ FileSystem, FileNotFoundException } = require './FileSystem'
Fallback = require './builders/Fallback'
express = require 'express'
socketio = require 'socket.io'
path = require 'path'
url = require 'url'

get_socketio_code_for = (builder) ->
  """
<script src="/socket.io/socket.io.js"></script>
<script type="text/javascript">
(function() {
  var socket = io.connect('/webapp');
  function register() {
    socket.emit('register', {
      root: "#{builder.getPath()}"
    });
  }
  socket.on('connect', register);
  socket.on('message', function(msg) {
    console.log("Message from socket.io", msg);
  });
  socket.on('refresh', function(reason) {
    if (reason) {
      console.log(reason);
    }
    location.reload();
  });
})();
</script>
"""

exports.middleware = (args) ->
  clients = {}
  known_deps = {}

  manager = new BuildManager args
  manager.fs.on FileSystem.FILE_CHANGED, (event, node, stat, old_stat) ->
    # event is one of new, unlink, change

    # XXX this might be overriden and doesn't handle dependent makefiles
    if node.getPath() is "Makefile.coffee" or node.getPath() is "Makefile.js"
      console.log "Reloading makefiles and all clients because #{node} " +
        "was modified..."
      manager.reset()
      c.socket.emit 'refresh' for id, c of clients
      return

    targets = manager.findTargetsAffectedBy node

    for t in targets when t.isDynamicallyGenerated
      # If a dynamically generated target was registered for this node, we need
      # to kill it and re-resolve the target (which might result in a new
      # dynamically-generated target).
      manager.unregister t

    for t in targets
      for dep, dep_list of known_deps when dep_list[t.getPath()] or
                                           dep is t.getPath()
        if manager.getOption('verbose') >= 1
          console.log "Refreshing #{dep} because #{t.target.getPath()} " +
            "has changed."
        for id, c of clients when c.on_page is dep
          c.socket.emit 'refresh',
            "Refreshing page because #{node} changed, which affects #{t}."

      # Also clear the deps if the target itself changed
      delete known_deps[t.getPath()]

  if args.fallthrough is false
    fallback_builder = new Fallback '%%', [],
      manager: manager

  args.socketIOManager?.of('/webapp').on 'connection', (socket) ->
    socket.on 'register', (data) ->
      me = clients[socket.id] = {}

      me.socket = socket
      me.on_page = data.root
      known_deps[me.on_page] ?= {}

      node = manager.fs.resolve data.root
      builder = manager.resolve node
      unless builder?
        # We don't have a rule for this thing? The client needs to do a refresh
        # to regenerate the dynamic rule.
        if manager.getOption('verbose') >= 1
          console.log "Refreshing #{me.on_page} because #{node} has no " +
            "Builders. (Possible server restart?)"
        socket.emit 'refresh', "Refreshing page because #{node} has no " +
          "Builders. (Possible server restart?)"

      socket.on 'disconnect', ->
        delete clients[socket.id]

  map_url_to_node = (url_string) ->
    url_string = url.parse(url_string).pathname
    url_string += "index.html" if url_string.substr(-1) == "/"
    url_string = path.join manager.getOption('targetPath'),
                    url_string.substring 1
    manager.fs.resolve url_string


  middleware = (req, res, next) ->
    target = map_url_to_node req.url

    try
      if target.getStat().isDirectory() and request_url.substr(-1) != "/"
        # For directories, redirect to the trailing / form. This will cause us
        # to realize we are dealing with a directory and serve index.html
        # appropriately.
        res.redirect "#{req.url}/"
        res.end()
        return
    catch _
      # Suck up a FileNotFoundException

    builder = manager.resolve target
    missing_files = []
    unless builder?
      builder = Builder.createBuilderFor manager, target, missing_files

    if builder?
      console.log "#{req.url} will be built by #{builder}" if args.verbose > 0

    else if args.fallthrough is false
      builder = new Fallback target, [ ], manager: manager
      builder.impliedSources = (manager.fs.resolve f for f in missing_files)
      manager.register builder

    else
      return next()

    if builder instanceof Fallback
      res.statusCode = 404

    if req.headers.referer?
      referer = map_url_to_node req.headers.referer
      deps = known_deps[referer.getPath()] ?= {}
      # Referer must depend on this file (except for refreshes)
      deps[target.getPath()] = true unless referer.equals target

    builder.getData (err, data) ->
      return next err if err?
      if builder.getMimeType() is "text/html"
        data = data.toString() + get_socketio_code_for builder
      res.setHeader 'Content-Type', builder.getMimeType()
      res.setHeader 'Content-Length', data.length
      res.write data
      res.end()

exports.standalone = (args) ->
  args.fallthrough = false
  args.watchFileSystem = true

  app = express.createServer()
  args.socketIOManager = socketio.listen app,
    'log level': 1

  app.use exports.middleware args
  app.use express.errorHandler
    showStack: true
    dumpExceptions: true

  server = app.listen args.port
  console.log "Server now live at http://localhost:#{server.address().port}/"
