require.paths.unshift "./support/express/lib"
require.paths.unshift "./support/node-discount/build/default"
require.paths.unshift "./support/redis-node-client/lib"

require "express"
require "express/plugins"
require "./lib/util"

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
    # @todo: fix possible security hole
    path.exists __dirname + @url.pathname, (exists) =>
        if exists 
            @sendfile __dirname + @url.pathname 
        else 
            @render file + ".css.sass", { layout: no }

get "/category.json", ->
    Category.recursive redis.ds(), (err, categories) =>
        respondWithJSON this, -> 
            if err then error err else categories

get "/category", ->
    Category.recursive redis.ds(), (err, categories) =>
        # @todo: handle error
        @render "category.html.haml", {
            locals: {
                title: 'Categories', 
                categories: categories
            }
        }

put "/category", ->
    name: sanitize @param "name"
    if not name then return respondWithError this, "need parameter 'name'"
    parent: sanitize @param "parent"
    if not parent then return respondWithError this, "need parameter 'parent'"
    category: Category.make name
    category.parent: parent
    category.insert redis.ds(), (err) =>
        respondWithJSON this, ->
            if err then error err else category

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
    name: sanitize @param "q"
    if not name then return @respond 500, "need parameter 'q'"
    limit: @param("limit") or -1
    if typeof limit isnt "number"
        return @respond 500, "parameter 'limit' must be a number"
    Category.findByPartialName redis.ds(), name, limit, (err, categories) =>
        if err then return @respond 500, err
        @contentType "text"
        @respond 200, (c.name for c in categories).join("\n")

get "/category/search/:name", (name) ->
    name: sanitize name
    Category.findByPartialName redis.ds(), name, -1, (err, categories) =>
        respondWithJSON this, ->
            if err then error err else categories

get "/category/*.json", (slug) ->
    slug: sanitize slug
    Category.findBySlug redis.ds(), slug, (err, category) =>
        respondWithJSON this, ->
            if err then error err else category

get "/category/*", (slug) ->
    ds: redis.ds()
    slug: sanitize slug
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

put "/fact", ->
    content: sanitize @param "content"
    if not content then return respondWithError this, "need parameter 'content'"
    category: sanitize @param "category"
    if not category then return respondWithError this, "need parameter 'category'"
    fact: Fact.make content
    fact.categories.push category
    fact.insert redis.ds(), (err) =>
        respondWithJSON this, ->
            if err then error err else fact

post "/fact/move/:key", (key) ->
    ds: redis.ds()
    key: sanitize key
    oldCategory: sanitize @param "old_category"
    if not oldCategory then return respondWithParamError this, "old_category"
    newCategory: sanitize @param "new_category"
    if not newCategory then return respondWithParamError this, "new_category"
    Fact.exists ds, key, (err, exists) =>
        if err then return respondWithJSON this, -> error err
        if not exists 
            return respondWithError this, "no fact with key '$key'"
        Fact.move ds, key, oldCategory, newCategory, (err) =>
            respondWithJSON this, ->
                if err then error err else { "msg": "OK" }

get "/fact/:key.json", (key) ->
    key: sanitize key
    Fact.findByKey redis.ds(), key, (err, fact) =>
        respondWithJSON this, ->
            if err then error err else fact

del "/fact/:key", (key) ->
    ds: redis.ds()
    key: sanitize key
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

respondWithParamError: (express, param) ->
    respondWithError express, "need parameter '$param'"

respondWithJSON: (express, callback) ->
    express.contentType "text"
    express.respond 200, JSON.encode callback()

run 5678

