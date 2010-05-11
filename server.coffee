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
    use MethodOverride
    use Static

commented: ->
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
    Category.recursive redis.client(), (err, categories) =>
        respondWithJSON this, -> 
            if err then error err else categories

get "/category/all", ->
    Category.all redis.client(), (err, categories) =>
        respondWithJSON this, -> 
            if err then error err else categories

post "/category", ->
    insert: =>
        category.insert redis.client(), (err) =>
            respondWithJSON this, ->
                if err then error err else category
    name: @param "name"
    if not name then return respondWithError this, "need parameter 'name'"
    parentName: @param "parent_name"
    category: Category.make name
    if not parentName
        insert()
    else
        Category.findByName redis.client(), parentName, (err, parent) =>
            if err then return respondWithJSON this, -> error err
            if not parent then return respondWithJSON this, -> 
                error "no such parent category"
            category.parent = parent.key
            insert()

get "/category/new", ->
    this.render "category.new.html.haml", {
        locals: {
            title: 'New Category'
        }
    }

get "/category/search", ->
    name: @param "q"
    if not name then return @respond 500, "need parameter 'q'"
    limit: @param(name) or -1
    Category.findByPartialName redis.client(), name, limit, (err, categories) =>
        if err then return respond 500, err
        @contentType "text"
        @respond 200, (c.name for c in categories).join("\n")

get "/category/search/:name", (name) ->
    Category.findByPartialName redis.client(), name, -1, (err, categories) =>
        respondWithJSON this, ->
            if err then error err else categories

get "/category/*", (slug) ->
    Category.findBySlug redis.client(), slug, (err, category) =>
        respondWithJSON this, ->
            if err then error err else category

#
# Helpers
#

error: (err) ->
    { "err": err.message }

respondWithError: (express, msg) ->
    respondWithJSON express, -> error new Error(msg)

respondWithJSON: (express, callback) ->
    express.contentType "text"
    express.respond 200, JSON.encode callback()

run 5678

