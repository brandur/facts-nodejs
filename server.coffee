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
    client: redis.client()
    category: new Category(name)
    category.insert client, (err) ->
        if err then throw new Error(err)
        self.contentType "text/json"
        self.halt 200, category.toJSON()

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

