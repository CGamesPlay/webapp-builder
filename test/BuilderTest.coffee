Builder = require '../lib/Builder'
Maker = require '../lib/Maker'
NodeMock = require './mock/NodeMock'
chai = require 'chai'

expect = chai.expect

describe 'Builder', ->
  noPrefix = -> "."

  NodeMock.use
    "test.txt": "It works!"
    "something.coffee": "coffeescript"

  beforeEach ->
    @maker = new Maker
      disableBuiltin: true
      sourcePath: '.'
      targetPath: 'out'
    @specific_file = Builder.Copy.factory 'test.txt',
      maker: @maker
    @wildcard_file = Builder.Copy.factory '%%.txt',
      maker: @maker
    @dependent_file = Builder.AppCache.factory 'app.cache', @specific_file,
      maker: @maker

  describe "#factory", ->
    it "refers to source files", ->
      getter = @wildcard_file.sources[0].prefixGetter
      expect(getter).to.equal(@maker.getSourcePath)

  describe "#inferTarget", ->
    class WithSuffix extends Builder
      @targetSuffix: '.js'

    beforeEach ->
      @builder = WithSuffix.factory "%%.coffee"
        maker: @maker

    it "works", ->
      expect(@builder.target.name).to.equal("%%.js")
      expect(@builder.target.prefixGetter).to.equal(@maker.getTargetPath)

    it "handles suffixes", ->
      target = @builder.inferTarget()
      expect(target.name).to.equal("%%.js")

  describe "#getBuilderFor", ->
    it "resolves wildcards", ->
      target = @wildcard_file.getBuilderFor 'test.txt'
      expect(target).to.exist
      expect(target.name).to.equal "test.txt"

  describe "#isAffectedBy", ->
    it "handles static filenames", ->
      file = NodeMock.resolve "test.txt", noPrefix
      ret = @specific_file.isAffectedBy file
      expect(ret).to.be.true

    it "ignores incorrect static filenames", ->
      file = NodeMock.resolve "something.coffee", noPrefix
      ret = @specific_file.isAffectedBy file
      expect(ret).to.be.false

    it "handles wildcards", ->
      file = NodeMock.resolve "test.txt", noPrefix
      ret = @wildcard_file.isAffectedBy file
      expect(ret).to.be.true

    it "ignores incorrect wildcards", ->
      file = NodeMock.resolve "something.coffee", noPrefix
      ret = @wildcard_file.isAffectedBy file
      expect(ret).to.be.false

    it "cascades", ->
      file = NodeMock.resolve "test.txt", noPrefix
      ret = @dependent_file.isAffectedBy file
      expect(ret).to.be.true
