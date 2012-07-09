NodeMock = require './mock/NodeMock'
chai = require 'chai'

expect = chai.expect

describe "NodeMock", ->
  noPrefix = -> '.'

  NodeMock.use
    "test.txt": "It works!"
    "out": {}
    "prefix":
      "test2.txt": "second test file"

  describe "#resolve", ->
    it "resolves files", ->
      file = NodeMock.resolve "test.txt", noPrefix
      expect(file).to.be.an.instanceof(NodeMock.File)
      expect(file.exists()).to.be.true

    it "resolves nonexistent files", ->
      file = NodeMock.resolve "404.txt", noPrefix
      expect(file).to.not.be.an.instanceof(NodeMock.File)
      expect(file.exists()).to.be.false

    it "resolves directories", ->
      dir = NodeMock.resolve "out", noPrefix
      expect(dir).to.be.an.instanceof(NodeMock.Dir)
      expect(dir.exists()).to.be.true

    it "resolves with prefixes", ->
      file = NodeMock.resolve "test2.txt", -> "prefix"
      expect(file).to.be.an.instanceof(NodeMock.File)
      expect(file.exists()).to.be.true

describe "NodeMock.File", ->
  noPrefix = -> '.'

  NodeMock.use
    "test.txt": "test.txt file contents"

  describe "#getData", ->
    it "returns the correct data", (next) ->
      file = NodeMock.resolve "test.txt", noPrefix
      file.getData (err, data) ->
        expect(err).to.be.null
        expect(data).to.equal "test.txt file contents"
        next()

describe "NodeMock.Wildcard", ->
  noPrefix = -> '.'
  withPrefix = -> "public"

  NodeMock.use
    "test.txt": "test.txt file contents"
    "public":
      "other.txt": "other file"

  describe "#refersTo", ->
    it "includes files inside prefix", ->
      wildcard = NodeMock.resolve "%%.txt", withPrefix
      inside_file = NodeMock.resolve "test.txt", withPrefix
      expect(wildcard.refersTo inside_file).to.be.true

    it "excludes files outside prefix", ->
      wildcard = NodeMock.resolve "%%.txt", withPrefix
      outside_file = NodeMock.resolve "test.txt", noPrefix
      expect(wildcard.refersTo outside_file).to.be.false
