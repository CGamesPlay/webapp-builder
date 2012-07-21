{ EventEmitter } = require 'events'

module.exports = class Reporter extends EventEmitter
  @VERBOSE: 5
  @DEBUG: 4
  @INFO: 3
  @WARNING: 2
  @ERROR: 1
  @FATAL: 0

  constructor: (options) ->
    @logLevel = options?.verbose ? Reporter.INFO

  setLogLevel: (@logLevel) ->

  verbose: (args...) -> @logv Reporter.VERBOSE, args
  debug: (args...) -> @logv Reporter.DEBUG, args
  info: (args...) -> @logv Reporter.INFO, args
  warning: (args...) -> @logv Reporter.WARNING, args
  error: (args...) -> @logv Reporter.ERROR, args
  fatal: (args...) -> @logv Reporter.FATAL, args

  logv: (level, args) ->
    @emit 'log', level, args
    if @logLevel >= level
      if level <= Reporter.WARNING
        console.error args...
      else
        console.log args...

