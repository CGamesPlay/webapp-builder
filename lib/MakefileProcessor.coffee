{ Builder } = require './Builder'
BuildManager = require './BuildManager'
CoffeeScript = require 'coffee-script'
fs = require 'fs'
path = require 'path'
vm = require 'vm'

module.exports = class MakefileProcessor
  constructor: (@manager, @options) ->
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
      @manager.reporter.error "Error file parsing #{filename ? 'makefile'}:\n" +
        munged_stack
    @

  # Install the necessary functions into the Makefile context.
  prepareEnvironment: (env) ->
    # General stuff
    env.console = console
    env.require = require

    # Webapp features
    wrap_factory = (type) => (args...) =>
      [ target, sources, options ] = Builder.parseArguments args

      options.manager = @manager

      builder = new type(target, sources, options)
      @manager.register builder
      builder

    env[k] = wrap_factory v for k, v of Builder.builderTypes
    env.SetOptions = @setBuilderOptions
    env.args = @options
    env.manager = @manager
    @

  setBuilderOptions: (options) =>
    @manager.setOption k, v for k, v of options
    @
