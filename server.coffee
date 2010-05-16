require.paths.unshift "./support/express/lib"
require.paths.unshift "./support/redis-node-client/lib"

require "express"
require "express/plugins"

path:  require "path"
redis: require "./lib/redis"
sys:   require "sys"

Category: require("./models/category").Category
Fact:     require("./models/fact").Fact

#
# Configuration ----
#

configure ->
    /* required so that Express can find our views */
    set "root", __dirname
    use MethodOverride
    use Static

comment: ->
    process.addListener "uncaughtException", (err) ->
        sys.error "Caught exception: " + err

#
# Routes ----
#

get "/public/css/*.css", (file) ->
    path.exists __dirname + @url.pathname, (exists) =>
        if exists 
            @sendfile __dirname + @url.pathname 
        else 
            @render file + ".css.sass", { layout: no }

get "/category", ->
    Category.recursive redis.ds(), (err, categories) =>
        respondWithJSON this, -> 
            if err then error err else categories

put "/category", ->
    insert: =>
        category.insert redis.ds(), (err) =>
            respondWithJSON this, ->
                if err then error err else category
    name: @param "name"
    if not name then return respondWithError this, "need parameter 'name'"
    parentName: @param "parent_name"
    category: Category.make name
    if not parentName
        insert()
    else
        Category.findByName redis.ds(), parentName, (err, parent) =>
            if err then return respondWithJSON this, -> error err
            if not parent then return respondWithJSON this, -> 
                error "no such parent category"
            category.parent = parent.key
            insert()

get "/category/all", ->
    Category.all redis.ds(), (err, categories) =>
        respondWithJSON this, -> 
            if err then error err else categories

get "/category/new", ->
    @render "category.new.html.haml", {
        locals: {
            title: 'New Category'
        }
    }

get "/category/search", ->
    name: @param "q"
    if not name then return @respond 500, "need parameter 'q'"
    limit: @param(name) or -1
    Category.findByPartialName redis.ds(), name, limit, (err, categories) =>
        if err then return respond 500, err
        @contentType "text"
        @respond 200, (c.name for c in categories).join("\n")

get "/category/search/:name", (name) ->
    Category.findByPartialName redis.ds(), name, -1, (err, categories) =>
        respondWithJSON this, ->
            if err then error err else categories

get "/category/*.json", (slug) ->
    Category.findBySlug redis.ds(), slug, (err, category) =>
        respondWithJSON this, ->
            if err then error err else category

get "/category/*", (slug) ->
    ds: redis.ds()
    Category.findBySlug ds, slug, (err, category) =>
        # @todo: check for error
        category.loadFacts ds, (err) =>
            category.loadParent ds, (err) =>
                category.loadChildrenWithFacts ds, (err) =>
                    @render "category.view.html.haml", {
                        locals: {
                            title: "$category.name ($category.slug)", 
                            category: category
                        }
                    }

del "/fact/:key", (key) ->
    ds: redis.ds()
    Fact.findByKey ds, key, (err, fact) =>
        if err then return respondWithJSON this, -> error err
        fact.destroy ds, (err) =>
            respondWithJSON this, ->
                if err then error err else { "msg": "OK" }

#
# Private ----
#

error: (err) ->
    { "err": err.message }

respondWithError: (express, msg) ->
    respondWithJSON express, -> error new Error(msg)

respondWithJSON: (express, callback) ->
    express.contentType "text"
    express.respond 200, JSON.encode callback()

run 5678

