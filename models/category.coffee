model: require "../lib/model"
redis: require "../lib/redis"
slug:  require "../lib/slug"
uuid:  require "../lib/uuid"

sys:  require "sys"

class exports.Category

    constructor: ->
        @children: {}

    insert: (client, callback) ->
        @key: uuid.make()
        client.setnx "category:slug:$@slug:key", @key, (err, reply) => 
            if err then return callback err
            client.set "category:name:$@name:key", @key, (err, reply) =>
                save: => model.save client, "category", @serialize(), (err, reply) =>
                    if err then return callback err
                    client.sadd "category:all", @key, (err, reply) ->
                        if err then return callback err
                        callback null
                if err then return callback err
                if reply is 0 
                    return callback new Error("category with that slug already exists")
                if not @parent
                    save()
                else
                    exports.Category.exists client, @parent, (err, exists) =>
                        if err then return callback err
                        if not exists 
                            return callback "parent key '$@parent' does not exist"
                        client.sadd "category:$@parent:children", @key, (err, reply) =>
                            if err then return callback err
                            save()

    serialize: ->
        {
            key: @key
            name: @name
            slug: @slug
            parent: @parent
        }

    toJSON: ->
        @serialize()

    @all: (client, callback) ->
        client.smembers "category:all", (err, keys) ->
            if err then return callback err, null
            exports.Category.findByKeys client, (k.toString() for k in keys), (err, categories) ->
                if err then return callback err, null
                callback null, categories

    @exists: (client, key, callback) ->
        client.get "category:$key:name", (err, reply) ->
            if err then return callback err, null
            callback null, reply isnt null

    @fields: ->
        ["name", "slug", "parent"]

    @findByKey: (client, key, callback) ->
        exports.Category.findByKeys client, [key], (err, categories) ->
            if err then return callback err, null
            callback null, categories[0]

    @findByKeys: (client, keys, callback) ->
        model.load client, "category", @fields(), keys, (-> new exports.Category()), callback

    @findByName: (client, name, callback) ->
        client.get "category:name:$name:key", (err, reply) ->
           if err then return callback err, null
           if not reply then return callback null, null
           exports.Category.findByKey client, reply.toString(), callback

    @findByPartialName: (client, name, limit, callback) ->
        # Redis treats '*' as a wildcard, this is our only tool for searching
        client.keys "category:slug:*$name*:key", (err, keys) ->
            if err then return callback err, null
            if not keys then return callback null, []
            # hopefully we won't have to split() on this in the future
            keys = keys.toString().split(" ")
            if limit > 0 and keys.length > limit
                keys = keys.slice(0, limit)
            redis.command client, "mget", keys, (err, keys2) ->
                if err then return callback err, null
                exports.Category.findByKeys client, (k.toString() for k in keys2), (err, categories) ->
                    if err then return callback err, null
                    callback null, categories

    @make: (name) ->
        category = new exports.Category()
        category.name: name
        category.slug: slug.make name
        category

