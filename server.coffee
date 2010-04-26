require "./models/category"
kiwi: require "kiwi"
redis: require "./lib/redis"
sys: require "sys"
kiwi.require "express"

process.addListener "uncaughtException", (err) ->
    sys.error "Caught exception: " + err

configure ->
    /* required so that Express can find our views */
    set "root", __dirname

get "/*.css", (file) ->
    this.render file + ".css.sass", { layout: false }

get "/category", ->
    this.render "category.new.html.haml", {
        locals: {
            title: 'New Category'
        }
    }

post "/category", ->
    name: this.param "name"
    if not name then throw Error("need name parameter")
    self: this
    slug: toSlug name
    key: uuid()
    client: redis.client()
    client.setnx "category:" + slug + ":key", key, (err, reply) ->
        if err then throw new Error(err)
        if reply is 0 then throw new Error("category already exists")
        client.mset "category:" + key + ":name", name, "category:" + key + ":slug", slug, (err, reply) ->
            if err then throw new Error(err)
            client.sadd "category:all", key, (err, reply) ->
                if err then throw new Error(err)
                self.contentType "text/json"
                self.halt 200, JSON.encode {
                    key: key, 
                    name: name, 
                    slug: slug
                }

get "/user/:id", (id) ->
    this.render "user.html.haml", {
        locals: {
            title: "User: " + id, 
            user: id, 
            slugstr: toSlug(id)
            uuid: uuid()
        }
    }

run 5678

