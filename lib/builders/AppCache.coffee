{ Builder } = require '../Builder'
async = require 'async'
crypto = require 'crypto'
fs = require 'fs'
path = require 'path'

Builder.registerBuilder class AppCache extends Builder
  constructor: (target, sources, options) ->
    super target, sources, options

  getData: (next) ->
    # Who needs efficiency? Not me!
    iterator = (source, next) ->
      source.getData (err, data) ->
        return next err if err?
        next null, crypto.createHash('sha1').update(data).digest('hex')
    async.mapSeries @sources, iterator, (err, sub_hashes) =>
      return next err if err?

      final_hash = crypto.createHash 'sha1'
      final_hash.update h for h in sub_hashes
      next null, @generateDocument
        cache_key: final_hash.digest 'hex'

  generateDocument: (options) ->
    document = """
    CACHE_MANIFEST
    # Cache key: #{options.cache_key}

    CACHE:

    """

    for s in @sources
      relative_path = path.relative path.dirname(@getPath()), s.getPath()
      document += relative_path + "\n"

    document += """

    NETWORK:
    *
    """
