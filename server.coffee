require.paths.unshift "./support/express/lib"
require.paths.unshift "./support/redis-node-client/lib"

require "express"
require "express/plugins"

path:  require "path"
redis: require "./lib/redis"
sys:   require "sys"

Category: require("./models/category").Category

#
# Configuration
#

configure ->
    /* required so that Express can find our views */
    set "root", __dirname
    use Static

comment: ->
    process.addListener "uncaughtException", (err) ->
        sys.error "Caught exception: " + err

#
# Routes
#

get "/public/css/*.css", (file) ->
    path.exists __dirname + @url.pathname, (exists) =>
        if exists 
            @sendfile __dirname + @url.pathname 
        else 
            @render file + ".css.sass", { layout: no }

get "/category", ->
    Category.all redis.client(), (err, categories) =>
        if err then return respondWithError this, err
        @contentType "text"
        @respond 200, JSON.encode categories

post "/category", ->
    name: checkParam this, "name"
    category: Category.make name
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

get "/category/search", ->
    name: checkParam this, "q"
    limit: checkParam this, "limit" or -1
    Category.findByPartialName redis.client(), name, limit, (err, categories) =>
        if err then return respondWithError this, err
        @contentType "text"
        # jquery.autocomplete only supports this ghetto table format for now
        @respond 200, (c.key + "|" + c.name for c in categories).join("\n")

get "/category/search/:name", (name) ->
    Category.findByPartialName redis.client(), name, -1, (err, categories) =>
        if err then return respondWithError this, err
        @contentType "text"
        @respond 200, JSON.encode categories

#
# Helpers
#

checkParam: (express, name) ->
    if not express.param name
        respondWithError express, "need parameter '" + name + "'"
    express.param(name)

respondWithError: (express, err) ->
    express.contentType "text"
    express.respond 200, JSON.encode { "err": err.message }

run 5678

