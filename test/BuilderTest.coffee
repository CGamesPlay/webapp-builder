Builder = require '../lib/Builder'
BuildManager = require '../lib/BuildManager'
NodeMock = require './mock/NodeMock'
chai = require 'chai'

expect = chai.expect

describe 'Builder', ->
  noPrefix = -> "."

  NodeMock.use
    "test.txt": "It works!"
    "something.coffee": "coffeescript"

  beforeEach ->
    @manager = new BuildManager
      disableBuiltin: true
      sourcePath: '.'
      targetPath: 'out'
    @specific_file = new Builder.Copy 'test.txt',
      manager: @manager
    @wildcard_file = new Builder.Copy '%%.txt',
      manager: @manager
    @dependent_file = new Builder.AppCache 'app.cache', @specific_file,
      manager: @manager

  describe "#constructor", ->
    it "refers to source files", ->
      getter = @wildcard_file.sources[0].prefixGetter
      expect(getter).to.equal(@manager.getSourcePath)

  describe "#inferTarget", ->
    class WithSuffix extends Builder
      @targetSuffix: '.js'

    beforeEach ->
      @builder = new WithSuffix "%%.coffee",
        manager: @manager

    it "works", ->
      expect(@builder.target.name).to.equal("%%.js")
      expect(@builder.target.prefixGetter).to.equal(@manager.getTargetPath)

    it "handles suffixes", ->
      target = @builder.inferTarget()
      expect(target.name).to.equal("%%.js")

  describe "#getBuilderFor", ->
    it "resolves static files", ->
      target_node = NodeMock.resolve 'test.txt', noPrefix
      target = @specific_file.getBuilderFor target_node
      expect(target).to.exist
      expect(target.name).to.equal 'test.txt'

    it "resolves wildcards", ->
      target_node = NodeMock.resolve 'test.txt', noPrefix
      target = @wildcard_file.getBuilderFor target_node
      expect(target).to.exist
      expect(target.name).to.equal 'test.txt'

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
