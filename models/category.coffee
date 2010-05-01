slug: require "../lib/slug"
uuid: require "../lib/uuid"

sys:  require "sys"

class exports.Category

    constructor: ->
        @children: {}

    insert: (client, callback) ->
        @key: uuid.make()
        client.setnx "category:" + @slug + ":key", @key, (err, reply) => 
            if err then return callback err
            if reply is 0 
                return callback new Error("category already exists")
            client.mset(
                "category:" + @key + ":name", @name, 
                "category:" + @key + ":slug", @slug, 
                "category:" + @key + ":parent", @parent, 
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
            parent: @parent
        }

    @all: (client, callback) ->
        client.smembers "category:all", (err, keys) ->
            if err then return callback err, null
            exports.Category.findByKeys client, (k.toString() for k in keys), (err, categories) ->
                if err then return callback err, null
                callback null, categories

    @findByKey: (client, key, callback) ->
        exports.Category.findByKeys client, [ key ], (err, categories) ->
            if err then return callback err, null
            callback null, categories[0]

    @findByKeys: (client, keys, callback) ->
        args = []
        for k in keys
            args.push "category:" + k + ":name"
            args.push "category:" + k + ":slug"
            args.push "category:" + k + ":parent"
        sendCommand client, "mget", args, (err, reply) ->
            if err then return callback err, null
            categories = []
            for i in [0...keys.length]
                c: new exports.Category()
                c.key:    keys[i]
                c.name:   reply[i * 3]?.toString()
                c.slug:   reply[i * 3 + 1]?.toString()
                c.parent: reply[i * 3 + 2]?.toString()
                categories.push c
            callback null, categories

    @findByPartialName: (client, name, callback) ->
        client.keys "category:*" + name + "*:key", (err, keys) ->
            if err then return callback err, null
            if not keys then return callback null, []
            # hopefully we won't have to split() on this in the future
            sendCommand client, "mget", keys.toString().split(" "), (err, keys2) ->
                if err then return callback err, null
                exports.Category.findByKeys client, (k.toString() for k in keys2), (err, categories) ->
                    if err then return callback err, null
                    callback null, categories

    @make: (name) ->
        category = new exports.Category()
        category.name: name
        category.slug: slug.make name
        category.children: {}
        category.parent: null
        category

sendCommand: (client, command, args, callback) ->
    client.sendCommand.apply client, [ command ].concat(args, [ callback ])

