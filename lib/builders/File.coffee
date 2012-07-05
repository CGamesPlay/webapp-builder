Builder = require '../Builder'
Node = require '../Node'

Builder.registerBuilder class File extends Builder
  toString: ->
    "File(#{@target?.toString()})"

  validateSources: ->
    if @sources.length != 1
      throw new Error "#{@} requires exactly one source."

  inferTarget: ->
    Node.resolve @sources[0], @maker.getTargetPath

  handleRequest: (req, res, next) ->
    if @sources[0] instanceof Node.Dir and req.url.substr(-1) != "/"
      # For directories, redirect to the trailing / form. This will cause the
      # server to realize it is dealing with a directory and serve index.html
      # appropriately.
      res.redirect "#{req.url}/"
      res.end()

    else
      super req, res, next

  getData: (next) ->
    @sources[0].getData next
