kiwi: require "kiwi"
redis: require "./lib/redis"
sys: require "sys"
kiwi.require "express"

Category: require("./models/category").Category

#
# Configuration
#

configure ->
    /* required so that Express can find our views */
    set "root", __dirname

process.addListener "uncaughtException", (err) ->
    sys.error "Caught exception: " + err

#
# Routes
#

get "/*.css", (file) ->
    this.render file + ".css.sass", { layout: false }

get "/category", ->
    this.render "category.new.html.haml", {
        locals: {
            title: 'New Category'
        }
    }

post "/category", ->
    name: checkParam(this, "name")
    client: redis.client()
    category: new Category(name)
    category.insert client, (err) =>
        if err then return respondWithError(this, err)
        @contentType "text"
        @halt 200, category.toJSON()

get "/user/:id", (id) ->
    @render "user.html.haml", {
        locals: {
            title: "User: " + id, 
            user: id, 
            slugstr: toSlug(id)
            uuid: uuid()
        }
    }

#
# Helpers
#

checkParam: (express, name) ->
    if not express.param(name) 
        respondWithError(express, "need parameter '" + name + "'")
    express.param(name)

respondWithError: (express, err) ->
    express.contentType "text"
    express.halt 500, JSON.encode { "err": err.message }

run 5678

