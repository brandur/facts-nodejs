slug: require "../lib/slug"
uuid: require "../lib/uuid"

class exports.Category

    constructor: (name) ->
        @name: name
        @slug: slug.make name

    @all: (client, callback) ->
        client.smembers "category:all", (err, keys) ->
            if err then return callback err, null
            sendCommand client, "mget", (("category:" + k + ":name") for k in keys), (err, reply) ->
                if err then return callback err, null
                categories = []
                for i in [0...keys.length]
                    c = new exports.Category reply[i].toString()
                    c.key = keys[i].toString()
                    categories.push c
                callback null, categories

    insert: (client, callback) ->
        @key: uuid.make()
        client.setnx "category:" + @slug + ":key", @key, (err, reply) => 
            if err then return callback err
            if reply is 0 
                return callback new Error("category already exists")
            client.mset(
                "category:" + @key + ":name", @name, 
                "category:" + @key + ":slug", @slug, 
                (err, reply) => 
                    if err then return callback err
                    client.sadd "category:all", @key, (err, reply) ->
                        if err then return callback err
                        callback null
            )

    toJSON: ->
        {
            key: @key
            name: @name
            slug: @slug
        }

sendCommand: (client, command, args, callback) ->
    client.sendCommand.apply client, [ command ].concat(args, [ callback ])

