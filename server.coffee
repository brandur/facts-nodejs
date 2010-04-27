require.paths.unshift "./support/express/lib"
require.paths.unshift "./support/redis-node-client/lib"

require "express"

redis: require "./lib/redis"
sys:   require "sys"

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
    Category.all redis.client(), (err, categories) =>
        if err then return respondWithError this, err
        @contentType "text"
        @respond 200, JSON.encode categories

post "/category", ->
    name: checkParam this, "name"
    category: new Category name
    category.insert redis.client(), (err) =>
        if err then return respondWithError this, err
        @contentType "text"
        @respond 200, JSON.encode category

get "/category/new", ->
    this.render "category.new.html.haml", {
        locals: {
            title: 'New Category'
        }
    }

#
# Helpers
#

checkParam: (express, name) ->
    if not express.param name
        respondWithError express, "need parameter '" + name + "'"
    express.param(name)

respondWithError: (express, err) ->
    express.contentType "text"
    express.respond 500, JSON.encode { "err": err.message }

run 5678

