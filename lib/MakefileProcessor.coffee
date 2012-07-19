{ Builder } = require './Builder'
BuildManager = require './BuildManager'
CoffeeScript = require 'coffee-script'
fs = require 'fs'
path = require 'path'
vm = require 'vm'

module.exports = class MakefileProcessor
  constructor: (@manager, @options) ->
    @vmContext = vm.createContext()

    @prepareEnvironment @vmContext
    @

  # Autodetect a Makefile if it exists and source it.
  loadDefault: ->
    for ext in [ '.coffee', '.js' ] when path.existsSync "Makefile#{ext}"
      @loadFile "Makefile#{ext}"
      break
    @

  # Given the actual path to a Makefile, load it.
  loadFile: (path) ->
    if @manager.getOption('verbose') >= 2
      console.log "\nLoading file: #{path}"

    code = fs.readFileSync path, 'utf-8'

    if path.substr(-7) == ".coffee"
      code = CoffeeScript.compile code

    @evaluateScript code

  evaluateScript: (code) ->
    vm.runInContext code, @vmContext, path
    @

  # Install the necessary functions into the Makefile context.
  prepareEnvironment: (env) ->
    wrap_factory = (type) => (args...) =>
      [ target, sources, options ] = Builder.parseArguments args

      options.manager = @manager

      builder = new type(target, sources, options)
      @manager.register builder
      builder

    env[k] = wrap_factory v for k, v of Builder.builderTypes
    env.SetOptions = @setBuilderOptions
    env.args = @options
    @

  setBuilderOptions: (options) =>
    @manager.setOption k, v for k, v of options
    @
