s: require "../lib/slug"
u: require "../lib/uuid"

class exports.Category
    constructor: (name) ->
        @name: name
        @slug: s.toSlug name

    insert: (client, callback) ->
        @key: u.uuid()
        obj: this
        client.setnx "category:" + obj.slug + ":key", obj.key, (err, reply) -> 
            if err then return callback(err)
            if reply is 0 
                return callback(new Error("category already exists"))
            client.mset "category:" + obj.key + ":name", obj.name, "category:" + obj.key + ":slug", obj.slug, (err, reply) ->
                if err then return callback(err)
                client.sadd "category:all", obj.key, (err, reply) ->
                    if err then return callback(err)
                    callback(null)

    toJSON: ->
        JSON.encode {
            key: @key, 
            name: @name, 
            slug: @slug
        }


