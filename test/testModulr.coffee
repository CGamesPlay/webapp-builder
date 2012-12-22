{ Builder, MissingDependencyError } = require '../lib/Builder'
BuildManager = require '../lib/BuildManager'
{ FileSystemMock, FileNotFoundException } = require './mock/FileSystemMock'
chai = require 'chai'

expect = chai.expect

describe 'Builder.Modulr', ->
  beforeEach ->
    @fs = new FileSystemMock
      "something.coffee": "require './module'"
      "module.coffee": "javascript"
      "test-vendor.coffee": "require 'underscore'"
      "uses-built.coffee": "require 'out/built'"
      "out":
        "something.js": "// prebuilt"
      "vendor":
        "underscore.js": "// using search paths"

    @manager = new BuildManager
      fileSystem: @fs
      sourcePath: '.'
      targetPath: 'out'
      modulrIncludePaths: [ "vendor" ]
    @dummy_builder = new Builder.Copy 'out/built.coffee', 'test-vendor.coffee',
      manager: @manager
    @builder = Builder.generateBuilder
      manager: @manager
      target: 'something.js'
    @manager
      .register(@dummy_builder)
      .register(@builder)

  describe "#resolveModule", ->
    it "handles variant paths", ->
      try
        Builder.Modulr.resolveModule @manager, "404", [ "out" ]
      catch err
        expect(err).to.be.an.instanceof FileNotFoundException
        sources = (s.getPath() for s in err.filenames)
        expect(sources).to.deep.equal [
          "out/404.js"
          "404.js"
          "out/404.coffee"
          "404.coffee"
        ]

    it "handles regular paths", ->
      try
        Builder.Modulr.resolveModule @manager, "404", [ "." ]
      catch err
        expect(err).to.be.an.instanceof FileNotFoundException
        sources = (s.getPath() for s in err.filenames)
        expect(sources).to.deep.equal [
          "404.js"
          "404.coffee"
        ]

    it "handles built sources", ->
      { tried, found } =
        Builder.Modulr.resolveModule @manager, "built", [ "out" ]

  describe "#queueBuild", ->
    it "can build with discovered sources", (next) ->
      @manager.make 'out/uses-built.js', (results) =>
        return next err for t, err of results when err?
        next()

  describe "#generateBuilder", ->
    it "correctly infers .js to .coffee", ->
      expect(@builder).to.exist
      expect(@builder).to.be.an.instanceof Builder.Modulr

  describe "#getData", ->
    it "finishes with the expected sources", (next) ->
      @builder.getData (err, data) =>
        return next err if err?

        sources = for s in @builder.impliedSources['modulr']
          s.getPath()
        expect(sources).to.deep.equal [
          # These files were actually used as deps
          'something.coffee'
          'module.coffee'
        ]
        sources = for s in @builder.impliedSources['modulr-alternates']
          s.getPath()
        expect(sources).to.deep.equal [
          # These files would have been picked up by Modulr if they existed
          'something.js'
          'module.js'
        ]
        next()

    it "handles search paths", (next) ->
      @builder = Builder.generateBuilder
        manager: @manager
        target: "test-vendor.js"

      @builder.getData (err, data) =>
        return next err if err?

        sources = for s in @builder.impliedSources['modulr']
          s.getPath()
        expect(sources).to.deep.equal [
          # These files would have been picked up by Modulr if they existed
          'test-vendor.coffee'
          'vendor/underscore.js'
        ]

        next()
