Builder = require '../lib/Builder'
BuildManager = require '../lib/BuildManager'
NodeMock = require './mock/NodeMock'
chai = require 'chai'

expect = chai.expect

describe 'BuildManager', ->
  noPrefix = -> '.'
  NodeMock.use
    "test.txt": "It works!"

  it "instantiates", ->
    new BuildManager
    expect(-> new BuildManager).to.not.throw()

  beforeEach ->
    @manager = new BuildManager
      disableBuiltin: yes
      sourcePath: '.'

    @wildcard = new Builder.Copy '%%',
      manager: @manager
    @cache_everything = new Builder.AppCache 'app.cache', @wildcard,
      manager: @manager

    @manager
      .register(@wildcard)
      .register(@cache_everything)

  describe "#resolve", ->
    it "identifies a target", ->
      target = NodeMock.resolve "app.cache", @manager.getTargetPath
      builder = @manager.resolve target
      expect(builder).to.exist
      expect(builder).to.equal(@cache_everything)

  describe "#findTargetsAffectedBy", ->
    it "identifies all targets", ->
      file = NodeMock.resolve "test.txt", noPrefix
      targets = @manager.findTargetsAffectedBy file
      expect(targets).to.have.length(2)
      expect(targets).to.contain @wildcard
      expect(targets).to.contain @cache_everything
