child_process = require 'child_process'
path = require 'path'
watchr = require 'watchr'

exports.AppMonitor = class AppMonitor
  @RESTART_DELAY = 250
  @IS_CHILD = no

  @main: =>
    @IS_CHILD = yes

    module = path.resolve process.argv[2]
    # Fix up argv so it looks like nothing is going on
    process.argv.splice 1, 1
    @hijackExtensions()
    require module

  @hijackExtensions: =>
    # XXX if you call hijackExtensions, THEN register a new extension, it won't
    # work :-/
    for ext, func of require.extensions
      require.extensions[ext] = @wrapExtension ext, func

    # Also watch all currently-loaded files. This shouldn't matter because it
    # will just this file and system dependencies, but better safe.
    files = (v.filename for k, v of require.cache)
    for f in files
      @watchFile f
    @

  @wrapExtension: (ext, func) => (module, filename) =>
    # Order is important here: if the function throws, the broken file will
    # still be monitored for changes (good for optional includes).
    @watchFile filename
    func module, filename

  @watchFile: (file) =>
    watchr.watch path: file, listener: @fileModified

  @fileModified: (event, path, stat, old_stat) =>
    console.log "Restarting server because #{path} changed."
    @restartApp()

  @restartApp: =>
    process.send "restart"

  constructor: (@args) ->

  start: ->
    throw new Error "AppMonitor.start can only be called once." if @child?
    module_path = path.join __dirname, "AppMonitor.child.js"
    @child = child_process.fork module_path, @args,
      env: process.env

    @child.on "message", (m) =>
      unless m is "restart"
        throw new Error "Unknown message received from child!"
      @restarting = true
      @child.kill()

    @child.on "exit", (code, signal) =>
      if @restarting
        @restarting = false
        @child = null
        @start()
