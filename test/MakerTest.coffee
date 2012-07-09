Builder = require '../lib/Builder'
Maker = require '../lib/Maker'
NodeMock = require './mock/NodeMock'
chai = require 'chai'

expect = chai.expect

describe 'Maker', ->
  noPrefix = -> '.'
  NodeMock.use
    "test.txt": "It works!"

  it "instantiates", ->
    expect(-> new Maker).to.not.Throw

  beforeEach ->
    @maker = new Maker
      disableBuiltin: yes
      sourcePath: '.'

    @wildcard = Builder.Copy.factory '%%',
      maker: @maker
    @cache_everything = Builder.AppCache.factory 'app.cache', @wildcard,
      maker: @maker

  describe "#findTargetsAffectedBy", ->
    it "identifies all targets", ->
      file = NodeMock.resolve "test.txt", noPrefix
      targets = @maker.findTargetsAffectedBy file
      expect(targets).to.have.length(2)
      expect(targets).to.contain @wildcard
      expect(targets).to.contain @cache_everything
