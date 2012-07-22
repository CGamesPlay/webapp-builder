{ FileSystem } = require './FileSystem'

exports.ClientManager = class ClientManager
  constructor: (@manager, @socket) ->
    @clients = {}
    @knownDeps = {}

    @manager.fs.startWatching()
    @manager.fs.on FileSystem.FILE_CHANGED, @fileModified
    @socket.of('/webapp').on 'connection', @clientConnected

  addClientSideDependency: (target, dep) ->
    deps = @knownDeps[target.getPath()] ?= {}
    unless deps[dep.getPath()]
      @manager.reporter.debug "#{target} has a client-side dependency on " +
        "#{dep}."
    deps[dep.getPath()] = true

  getTrailerFor: (builder) ->
    """
    <script src="/socket.io/socket.io.js"></script>
    <script type="text/javascript">
    (function() {
      var socket = io.connect('/webapp');
      socket.on('connect', function() {
        socket.emit('register', {
          root: "#{builder.getPath()}"
        });
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

  fileModified: (event, node, stat, old_stat) =>
    # event is one of new, unlink, change

    # XXX this might be overriden and doesn't handle dependent makefiles
    if node.getPath() is "Makefile.coffee" or node.getPath() is "Makefile.js"
      @manager.reporter.info "Reloading makefiles and all clients because " +
        "#{node} was modified..."
      @manager.reset()
      c.socket.emit 'refresh' for id, c of @clients
      return

    targets = @manager.findTargetsAffectedBy node

    for t in targets when t.isDynamicallyGenerated
      # If a dynamically generated target was registered for this node, we need
      # to kill it and re-resolve the target (which might result in a new
      # dynamically-generated target).
      @manager.unregister t

    for t in targets
      for dep, dep_list of @knownDeps when dep_list[t.getPath()] or
                                            dep is t.getPath()
        @manager.reporter.info "Refreshing #{dep} because " +
          "#{t.target.getPath()} has changed, which affects #{t}."
        for id, c of @clients when c.on_page is dep
          c.socket.emit 'refresh',
            "Refreshing page because #{node} changed, which affects #{t}."

      # Also clear the deps if the target itself changed
      delete @knownDeps[t.getPath()]

  clientConnected: (socket) =>
    socket.on 'register', (data) =>
      me = @clients[socket.id] = {}

      me.socket = socket
      me.on_page = data.root
      @knownDeps[me.on_page] ?= {}

      node = @manager.fs.resolve data.root
      builder = @manager.resolve node
      unless builder?
        # We don't have a rule for this thing? The client needs to do a refresh
        # to regenerate the dynamic rule.
        @manager.reporter.info "Refreshing #{me.on_page} because #{node} has " +
          "no Builders. (Possible server restart?)"
        socket.emit 'refresh', "Refreshing page because #{node} has no " +
          "Builders. (Possible server restart?)"

      socket.on 'disconnect', =>
        delete @clients[socket.id]
