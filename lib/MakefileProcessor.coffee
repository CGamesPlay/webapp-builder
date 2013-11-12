{ Builder } = require './Builder'
CoffeeScript = require 'coffee-script'
fs = require 'fs'
path = require 'path'
vm = require 'vm'

module.exports = class MakefileProcessor
  constructor: (@manager) ->
    @proxy = new ConfigurationProxy @manager
    @

  # Load the Makefile that is bundled with webapp
  loadBuiltin: ->
    @loadFile path.join __dirname, "DefaultMakefile.coffee"
    @

  # Autodetect a Makefile if it exists and source it.
  loadDefault: ->
    for ext in [ '.coffee', '.js' ] when fs.existsSync "Makefile#{ext}"
      @loadFile "Makefile#{ext}"
      break
    @

  # Given the actual path to a Makefile, load it.
  loadFile: (filename) ->
    @manager.reporter.verbose "\nLoading file: #{filename}"

    filename = path.resolve filename

    # XXX this should be in a separate context, but there's no way to make
    # require work with a separate context. This should also be done once at
    # initialization time, but mocha will fail tests for leaking globals.
    @prepareEnvironment global

    try
      # We copy require in from this file, which means it has this file's paths,
      # so we need to do another require on the Makefile to correct them.
      script = "require(#{JSON.stringify filename});"
      vm.runInThisContext script, __filename
    catch err
      munged_stack = err.stack
      cut_point = munged_stack.indexOf __filename
      if cut_point isnt -1
        cut_point = munged_stack.lastIndexOf("\n", cut_point)
        munged_stack = munged_stack.substr 0, cut_point
      @manager.reporter.error "Error while parsing #{filename}:\n" +
        munged_stack
    @

  # Install the necessary functions into the Makefile context.
  prepareEnvironment: (env) ->
    # General stuff
    env.console = console
    env.require = require
    # Webapp features
    env.webapp = @proxy
    env.Builder = Builder
    env[k] = v for k, v of Builder.builderTypes
    @

  setBuilderOptions: (options) =>
    @manager.setOption k, v for k, v of options
    @

class ConfigurationProxy
  constructor: (@manager) ->
    @server = @manager.server

  reset: ->
    @server.reset() if @server?
    @manager.reset()

  addBuilder: (builder) ->
    @manager.register builder

  addServerRule: (config) ->
    return unless @server?
    @server.addRule config

  getOption: (opt) -> @manager.getOption opt
  setOption: (opt, value) -> @manager.setOption opt, value
  setOptions: (config) ->
    @manager.setOption k, v for own k, v of config
