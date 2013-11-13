{ Builder } = require '../Builder'

# This is not a real builder. When called, it actually returns a new constructor
# which, when instantiated, returns a builder that builds the last step of the
# pipeline and has a dependency chain leading to the previous steps.
pipeline_generator = (builders) ->
  pipeline = (args...) ->
    [ final_target, sources, options ] = Builder.parseArguments args
    fs = options.manager.fs
    # Iterate through builders, building to int-#{i}-#{target}, and feeding
    # that as a source to the next builder
    for bld, i in builders
      if i is builders.length - 1
        target = final_target
      else
        target = fs.resolve "#{final_target.getPath()}.int#{i}"
      sources = [ new bld target, sources, options ]
    sources[0]

  pipeline.getName = ->
    "Pipeline [ #{(b.getName() for b in builders).join ', '} ]"

  pipeline

pipeline_generator.getName = -> "Pipeline"

Builder.registerBuilder pipeline_generator
