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
          root: #{JSON.stringify builder.getPath()}
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

    targets = @manager.findTargetsAffectedBy node

    for t in targets when t.isDynamicallyGenerated
      # If a dynamically generated target was registered for this node, we need
      # to kill it and re-resolve the target (which might result in a new
      # dynamically-generated target).
      @manager.unregister t

    for t in targets
      for dep, dep_list of @knownDeps when dep_list[t.getPath()] or
                                            dep is t.getPath()
        message = "Refreshing #{dep} because #{node} has changed, which " +
          "affects #{t}."
        @manager.reporter.info message
        for id, c of @clients when c.on_page is dep
          c.socket.emit 'refresh', message

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
