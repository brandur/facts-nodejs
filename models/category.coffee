require "../lib/util"

model: require "../lib/model"
redis: require "../lib/redis"
slug:  require "../lib/slug"
sys:   require "sys"
time:  require "../lib/time"
uuid:  require "../lib/uuid"

class Category

    #
    # Initialization ----
    #

    constructor: ->
        @children: []

    @make: (name) ->
        category: new Category()
        category.name: name
        category

    #
    # Persistence ----
    #

    insert: (client, callback) ->
        # Step 1: initialize members for insert and generate an appropriate 
        # slug
        start: =>
            @key: uuid.make()
            @createdAt: time.now()
            if not @parent
                @slug: slug.make @name
                insertSlug()
            else
                Category.exists client, @parent, errw callback, (exists) =>
                    if not exists then return callback(
                        new Error "parent key '$@parent' does not exist"
                    )
                    client.get "category:$@parent:slug", errw callback, (reply) =>
                        @slug: reply.toString() + "/" + slug.make @name
                        insertSlug()
        # Step 2: insert the slug, but fail if it's already present. Add this 
        # category to its parent's collection or a root collection.
        insertSlug: => 
            client.setnx "category:slug:$@slug:key", @key, errw callback, (reply) =>
                if reply is 0 
                    return callback(
                        new Error "category with that slug already exists"
                    )
                client.set "category:name:$@name:key", @key, errw callback, (reply) =>
                    if not @parent
                        # Indicate that this is a root-level category
                        client.sadd "category:root", @key, errw callback, (reply) =>
                            insertFields()
                    else
                        client.sadd "category:$@parent:children", @key, errw callback, (reply) =>
                            insertFields()
        # Step 3: persist the category's fields and add it to the 'all' set
        insertFields: => 
            model.save client, "category", @toFields(), errw callback, (reply) =>
                client.sadd "category:all", @key, errw callback, (reply) ->
                    callback null
        start()

    #
    # Lazy Initialization ----
    #

    loadChildren: (client, callback) ->
        if @children.length < 1 then return callback null
        Category.findByKeys client, @children, errw callback, (categories) =>
            @children: categories
            callback null

    loadChildrenRecursively: (client, callback) ->
        Category.loadCategories client, @categories, 0, callback

    #
    # Serialization ----
    #

    @fields: ->
        [ 
            "name"
            "slug"
            "parent"
            { obj: "createdAt", datastore: "created_at" }
        ]

    toFields: ->
        {
            key: @key
            name: @name
            slug: @slug
            parent: @parent
            created_at: @createdAt
        }

    toJSON: ->
        o: @toFields()
        o.children: @children
        o

    #
    # Sets ----
    #

    @all: (client, callback) ->
        client.smembers "category:all", errw2 callback, (keys) ->
            if not keys then return callback null, null
            keys: k.toString() for k in keys
            Category.findByKeys client, keys, errw2 callback, (categories) ->
                callback null, categories

    @recursive: (client, callback) ->
        Category.root client, errw2 callback, (categories) ->
            Category.loadCategories client, categories, 0, callback

    @root: (client, callback) ->
        client.smembers "category:root", errw2 callback, (keys) ->
            if not keys then return callback null, null
            keys: k.toString() for k in keys
            Category.findByKeys client, keys, errw2 callback, (categories) ->
                callback null, categories

    #
    # Find ----
    #

    @exists: (client, key, callback) ->
        client.get "category:$key:name", errw2 callback, (reply) ->
            callback null, reply isnt null

    @findByKey: (client, key, callback) ->
        Category.findByKeys client, [key], errw2 callback, (categories) ->
            callback null, categories[0]

    @findByKeys: (client, keys, callback) ->
        # Step 1: load fields for all requested keys using a big 'mget'
        start: =>
            model.load(client, "category", @fields(), keys, (-> new Category()), 
                errw2 callback, (categories) -> 
                    loadCollections client, categories, [], callback
            )
        # Step 2: load member collections for every object returned in the 1st 
        # step. This function traverses each object via recursion.
        loadCollections: (client, categories, collector, callback) ->
            category: categories.shift()
            if not category then return callback null, collector
            client.smembers "category:$category.key:children", errw2 callback, (children) ->
                if children 
                    category.children: c.toString() for c in children
                collector.push category
                loadCollections client, categories, collector, errw2 callback, (categories) ->
                    callback null, categories
        start()

    @findByName: (client, name, callback) ->
        client.get "category:name:$name:key", errw2 callback, (reply) ->
           if not reply then return callback null, null
           Category.findByKey client, reply.toString(), callback

    @findByPartialName: (client, name, limit, callback) ->
        # Redis treats '*' as a wildcard, this is our only tool for searching
        client.keys "category:name:*$name*:key", errw2 callback, (keys) ->
            if not keys then return callback null, []
            # hopefully we won't have to split() on this in the future
            keys: keys.toString().split(" ")
            if limit > 0 and keys.length > limit
                keys: keys.slice(0, limit)
            redis.command client, "mget", keys, errw2 callback, (keys) ->
                keys: k.toString() for k in keys
                Category.findByKeys client, keys, errw2 callback, (categories) ->
                    callback null, categories

    @findBySlug: (client, slug, callback) ->
        client.get "category:slug:$slug:key", errw2 callback, (reply) ->
           if not reply then return callback null, null
           Category.findByKey client, reply.toString(), callback

    #
    # Private ----
    #

    @loadCategories: (client, categories, i, callback) ->
        if i >= categories.length then return callback null, categories
        category: categories[i]
        category.loadChildren client, =>
            loadCategories client, category.children, 0, errw2 callback, (x) =>
                loadCategories client, categories, i+1, errw2 callback, (categories) =>
                    callback null, categories

exports.Category: Category

