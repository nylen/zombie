{ assert, brains, Browser } = require("./helpers")
File = require("fs")
Zlib = require("zlib")


describe "Resources", ->

  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)

  before ->
    brains.get "/resources/resource", (req, res)->
      res.send """
      <html>
        <head>
          <title>Whatever</title>
          <script src="/jquery.js"></script>
        </head>
        <body>Hello World</body>
        <script>
          document.title = "Nice";
          $(function() { $("title").text("Awesome") })
        </script>
        <script type="text/x-do-not-parse">
          <p>this is not valid JavaScript</p>
        </script>
      </html>
      """


  describe "as array", ->
    before (done)->
      browser.resources.length = 0
      browser.visit("/resources/resource", done)

    it "should have a length", ->
      assert.equal browser.resources.length, 2
    it "should include loaded page", ->
      assert.equal browser.resources[0].response.url, "http://example.com/resources/resource"
    it "should include loaded JavaScript", ->
      assert.equal browser.resources[1].response.url, "http://example.com/jquery-2.0.3.js"


  describe "fail URL", ->
    before (done)->
      browser.resources.fail("/resource/resource", "Fail!")
      browser.visit "/resource/resource", (@error)=>
        done()

    it "should fail the request", ->
      assert.equal @error.message, "Fail!"

    after ->
      browser.resources.restore("/resources/resource")


  describe "delay URL with timeout", ->
    before (done)->
      browser.resources.delay("/resources/resource", 150)
      browser.visit("/resources/resource")
      browser.wait(duration: 90, done)

    it "should not load page", ->
      assert !browser.document.body

    describe "after delay", ->
      before (done)->
        browser.wait(duration: 90, done)

      it "should successfully load page", ->
        browser.assert.text "title", "Awesome"

    after ->
      browser.resources.restore("/resources/resource")


  describe "mock URL", ->
    before (done)->
      browser.resources.mock("/resources/resource", statusCode: 204, body: "empty")
      browser.visit("/resources/resource", done)

    it "should return mock result", ->
      browser.assert.status 204
      browser.assert.text "body", "empty"

    describe "restore", ->
      before (done)->
        browser.resources.restore("/resources/resource")
        browser.visit("/resources/resource", done)

      it "should return actual page", ->
        browser.assert.text "title", "Awesome"


  describe "deflate", ->
    before ->
      brains.get "/resources/deflate", (req, res)->
        res.setHeader "Transfer-Encoding", "deflate"
        image = File.readFileSync("#{__dirname}/data/zombie.jpg")
        Zlib.deflate image, (error, buffer)->
          res.send(buffer)

    before (done)->
      browser.resources.get "http://example.com/resources/deflate", (error, @response)=>
        done()

    it "should uncompress deflated response with transfer-encoding", ->
      image = File.readFileSync("#{__dirname}/data/zombie.jpg")
      assert.deepEqual image, @response.body


  describe "deflate content", ->
    before ->
      brains.get "/resources/deflate", (req, res)->
        res.setHeader "Content-Encoding", "deflate"
        image = File.readFileSync("#{__dirname}/data/zombie.jpg")
        Zlib.deflate image, (error, buffer)->
          res.send(buffer)

    before (done)->
      browser.resources.get "http://example.com/resources/deflate", (error, @response)=>
        done()

    it "should uncompress deflated response with content-encoding", ->
      image = File.readFileSync("#{__dirname}/data/zombie.jpg")
      assert.deepEqual image, @response.body


  describe "gzip", ->
    before ->
      brains.get "/resources/gzip", (req, res)->
        res.setHeader "Transfer-Encoding", "gzip"
        image = File.readFileSync("#{__dirname}/data/zombie.jpg")
        Zlib.gzip image, (error, buffer)->
          res.send(buffer)

    before (done)->
      browser.resources.get "http://example.com/resources/gzip", (error, @response)=>
        done()

    it "should uncompress gzipped response with transfer-encoding", ->
      image = File.readFileSync("#{__dirname}/data/zombie.jpg")
      assert.deepEqual image, @response.body


  describe "gzip content", ->
    before ->
      brains.get "/resources/gzip", (req, res)->
        res.setHeader "Content-Encoding", "gzip"
        image = File.readFileSync("#{__dirname}/data/zombie.jpg")
        Zlib.gzip image, (error, buffer)->
          res.send(buffer)

    before (done)->
      browser.resources.get "http://example.com/resources/gzip", (error, @response)=>
        done()

    it "should uncompress gzipped response with content-encoding", ->
      image = File.readFileSync("#{__dirname}/data/zombie.jpg")
      assert.deepEqual image, @response.body


  describe "301 redirect URL", ->
    before ->
      brains.get "/resources/three-oh-one", (req, res)->
        res.redirect("/resources/resource", 301)

    before (done)->
      browser.resources.length = 0
      browser.visit("/resources/three-oh-one", done)

    it "should have a length", ->
      assert.equal browser.resources.length, 2
    it "should include loaded page", ->
      assert.equal browser.resources[0].response.url, "http://example.com/resources/resource"
    it "should include loaded JavaScript", ->
      assert.equal browser.resources[1].response.url, "http://example.com/jquery-2.0.3.js"

  describe "301 redirect URL cross server", ->
    before (done)->
      brains.get "/resources/3005", (req, res)->
        res.redirect("http://example.com:3005/resources/resource", 301)

      browser.resources.length = 0
      brains.listen 3005, ->
        browser.visit("/resources/3005", done)

    it "should have a length", ->
      assert.equal browser.resources.length, 2
    it "should include loaded page", ->
      assert.equal browser.resources[0].response.url, "http://example.com:3005/resources/resource"
    it "should include loaded JavaScript", ->
      assert.equal browser.resources[1].response.url, "http://example.com:3005/jquery-2.0.3.js"

  describe "request options", ->

    requests = []

    requestListener = (req) ->
      requests.push(req)

    redirectListener = (res, newReq) ->
      requests.push(newReq)

    before ->
      brains.get "/resources/three-oh-one", (req, res)->
        res.redirect("/resources/resource", 301)

      # Capture all requests that flow through the pipeline.
      browser.on "request", requestListener
      browser.on "redirect", redirectListener

    before (done)->
      browser.visit("/resources/three-oh-one", done)

    after ->
      browser.removeListener "request", requestListener
      browser.removeListener "redirect", redirectListener

    it "should include 'strictSSL' in options for all requests", ->
      # There will be at least the initial request and a second request to
      # follow the redirect.
      assert.ok requests.length > 1
      requests.forEach (req)->
        assert.strictEqual req.strictSSL, browser.strictSSL

  describe "addHandler", ->
    before (done) ->
      # WARNING: This handler is used for all remaining tests in the suite.
      browser.resources.addHandler (request, done) ->
        done(null, statusCode: 204, body: "empty")
      browser.visit("/resources/resource", done)

    it "should call the handler and use its response", ->
      browser.assert.status 204
      browser.assert.text "body", "empty"

  after ->
    browser.destroy()
