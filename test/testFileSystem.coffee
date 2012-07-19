{ expect } = require 'chai'
{ FileSystem, FileNotFoundException } = require '../lib/FileSystem'
{ FileSystemMock } = require './mock/FileSystemMock'

describe "FileSystem", ->
  beforeEach ->
    @fs = new FileSystem
    @fs.setVariantDir "out", "public"

  describe "#getVariantPath", ->
    it "modifies filenames inside the variant directory", ->
      path = @fs.getVariantPath "out/index.html"
      expect(path).to.equal("public/index.html")

    it "does not modify filenames outside the variant directory", ->
      path = @fs.getVariantPath "index.html"
      expect(path).to.equal("index.html")

describe "FileSystemMock", ->
  beforeEach ->
    @fs = new FileSystemMock {}

  describe "#mkdirp", ->
    it "makes faux directories", (done) ->
      @fs.mkdirp 'path/to/test', (err) =>
        return done err if err?
        file = @fs.getFile '/'
        expect(file).to.deep.equal
          path:
            to:
              test: {}
        done null

describe "FileSystemMock.Node", ->
  beforeEach ->
    @fs = new FileSystemMock
      "out":
        "index.js": "// A JS file"
      "public":
        "index.coffee": "# A coffeescript file"
        "index.html": "HTML!"

    @fs.setVariantDir "out", "public"

  describe "#getReadablePath", ->
    it "resolves for writing", ->
      node = @fs.resolve "out/index.html"
      expect(node).to.exist
      expect(node).to.be.an.instanceof(FileSystemMock.Node)
      expect(node.getPath()).to.equal "out/index.html"

    it "resolves for reading", ->
      node = @fs.resolve "out/index.html"
      expect(node).to.exist
      expect(node).to.be.an.instanceof(FileSystemMock.Node)
      expect(node.getReadablePath()).to.equal "public/index.html"

    it "errors when reading nonexistent file", ->
      node = @fs.resolve "404.txt"
      expect(-> node.getReadablePath()).to.throw(FileNotFoundException)
