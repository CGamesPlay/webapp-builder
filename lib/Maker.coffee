Builder = require './Builder'
CoffeeScript = require 'coffee-script'
Node = require './Node'
fs = require 'fs'
path = require 'path'
vm = require 'vm'

module.exports = class Maker
  @defaultOptions:
    sourcePath: path.resolve '.'
    targetPath: path.resolve 'out'

  constructor: (@externalOptions = {}) ->
    @reset()

  reset: ->
    @vmContext = vm.createContext()
    @options = {}
    @options[k] = v for k, v of Maker.defaultOptions
    @options[k] = v for k, v of @externalOptions
    @builders = []

    @prepareEnvironment @vmContext
    @loadBuiltinMakefile() unless @options.disableBuiltin
    @

  getSourcePath: => @options.sourcePath
  getTargetPath: => @options.targetPath

  # Load the built-in Makefile.
  loadBuiltinMakefile: ->
    @loadMakefile path.resolve __dirname, 'Makefile.default.coffee'
    @

  # Autodetect a Makefile if it exists and source it.
  loadDefaultMakefile: ->
    for ext in [ '.coffee', '.js' ]
      if path.existsSync "Makefile#{ext}"
        @loadMakefile "Makefile#{ext}"
        break
    @

  # Given the actual path to a Makefile, load it.
  loadMakefile: (path) ->
    code = fs.readFileSync path, 'utf-8'

    if path.substr(-7) == ".coffee"
      code = CoffeeScript.compile code

    @evaluateScript code

  evaluateScript: (code) ->
    Maker.currentMaker = @
    try
      vm.runInContext code, @vmContext, path
    finally
      Maker.currentMaker = undefined
    @

  # Install the necessary functions into the Makefile context.
  prepareEnvironment: (env) ->
    env[k] = v for k, v of Builder.builderTypes
    env.Node = Node
    env.SetOptions = @setOptions
    env.args = @options
    @

  setOptions: (options) =>
    @options[k] = v for k, v of options
    @

  registerBuilder: (builder) ->
    @builders.unshift(builder)
    if @options.verbose >= 1
      console.log "Added #{builder}"
    @

  resolve: (path) ->
    for try_builder in @builders
      actual_builder = try_builder.getBuilderFor path
      return actual_builder if actual_builder?
    null

  findTargetsAffectedBy: (path) ->
    b for b in @builders when b.isAffectedBy path
