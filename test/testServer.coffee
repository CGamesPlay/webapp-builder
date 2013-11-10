Fallback = require '../lib/builders/Fallback'
Server = require '../lib/Server'
{ Builder } = require '../lib/Builder'
{ FileSystemMock, FileNotFoundException } = require './mock/FileSystemMock'
{ expect } = require 'chai'

fake_request = (server, url, next) ->
  req = url: url, headers: {}
  res =
    headers: {}
    data: ""
    redirect: (url) ->
      @redirectedTo = url
    setHeader: (name, value) ->
      @headers[name] = value
    write: (data) ->
      @data += data
    end: (data) ->
      @data += data if data?
      process.nextTick -> next res
  server.middleware req, res, -> process.nextTick -> next null

describe 'Server', ->
  describe "#middleware", ->
    beforeEach ->
      @fs = new FileSystemMock
        "out":
          "directory": {}
        "directory":
          "index.html": "Index!"
      @server = new Server
        fileSystem: @fs
      @server.setFallthrough no

    it "appends / to directories", (next) ->
      fake_request @server, '/directory', (res) ->
        expect(res.redirectedTo).to.equal('/directory/')
        next()

    it "serves index.html for paths ending in /", (next) ->
      called = no
      @server.staticServer = (req, res, next) ->
        called = yes
        res.end()
      fake_request @server, '/directory/', (res) ->
        expect(called).to.equal(yes)
        next()

  describe "#generateBuilder", ->
    beforeEach ->
      @fs = new FileSystemMock
        "index.html": "HTML file"
        "copy.css": "/* CSS File */"
      @server = new Server
        fileSystem: @fs

    it "can resolve a copy rule", ->
      builder = @server.generateBuilder "out/copy.css"
      expect(builder).to.be.an.instanceof(Builder.Copy)
      expect(builder.sources[0].getPath()).to.equal("copy.css")
      expect(builder.target.getPath()).to.equal("out/copy.css")

    it "can resolve a higher-precedence rule", ->
      builder = @server.generateBuilder "out/index.html"
      expect(builder).to.be.an.instanceof(Builder.AutoRefresh)

    it "does not resolve missing files", ->
      @server.setFallthrough no
      builder = @server.generateBuilder "out/404.txt"
      expect(builder).to.be.an.instanceof(Fallback)
      alternates = (n.getPath() for n in builder.impliedSources["alternates"])
      expect(alternates).to.contain("404.txt")

    it "sets alternates on resolved files", ->
      builder = @server.generateBuilder "out/copy.css"
      expect(builder).to.be.an.instanceof(Builder.Copy)
      alternates = (n.getPath() for n in builder.impliedSources["alternates"])
      expect(alternates).to.contain("copy.less")

describe 'Server.Rule', ->
  describe "#matches", ->
    it "matches literal paths", ->
      rule = new Server.Rule target: "/robots.txt", source: "rbt.txt"
      expect(rule.matches "/robots.txt").to.equal(true)
      expect(rule.getSourcePaths("/robots.txt")[0]).to.equal("rbt.txt")
      expect(rule.matches "/index.html").to.equal(false)

    it "matches with no anchors", ->
      rule = new Server.Rule target: "%", source: "a/%/b"
      expect(rule.matches "/robots.txt").to.equal(true)
      expect(rule.getSourcePaths("/robots.txt")[0])
        .to.equal("a//robots.txt/b")

    it "matches trailing anchors", ->
      rule = new Server.Rule target: "%.js", source: "src/%.coffee"
      expect(rule.matches "/main.js").to.equal(true)
      expect(rule.getSourcePaths("/main.js")[0]).to.equal("src//main.coffee")
      expect(rule.matches "/main.js.gz").to.equal(false)

    it "matches leading anchors", ->
      rule = new Server.Rule target: "/images/%", source: "img/%"
      expect(rule.matches "/images/png.png").to.equal(true)
      expect(rule.getSourcePaths("/images/png.png")[0])
        .to.equal("img/png.png")
      expect(rule.matches "/public/images/png.png").to.equal(false)

    it "matches both anchors", ->
      rule = new Server.Rule target: "/css/%.css", source: "less/%.less"
      expect(rule.matches "/css/tests.css").to.equal(true)
      expect(rule.getSourcePaths("/css/tests.css")[0])
        .to.equal("less/tests.less")

    it "ignores empty matches", ->
      rule = new Server.Rule target: "%.css"
      expect(rule.matches ".css").to.equal(false)
