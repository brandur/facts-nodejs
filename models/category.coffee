slug: require "../lib/slug"
uuid: require "../lib/uuid"

class exports.Category

    constructor: (name) ->
        @name: name
        @slug: slug.make name

    insert: (client, callback) ->
        @key: uuid.make()
        client.setnx "category:" + @slug + ":key", @key, (err, reply) => 
            if err then return callback(err)
            if reply is 0 
                return callback(new Error("category already exists"))
            client.mset(
                "category:" + @key + ":name", @name, 
                "category:" + @key + ":slug", @slug, 
                (err, reply) => 
                    if err then return callback(err)
                    client.sadd "category:all", @key, (err, reply) ->
                        if err then return callback(err)
                        callback(null)
            )

    toJSON: ->
        JSON.encode {
            key: @key, 
            name: @name, 
            slug: @slug
        }


