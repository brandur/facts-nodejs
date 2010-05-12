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

    insert: (client, cb) ->
        # Step 1: initialize members for insert and generate an appropriate 
        # slug
        start: =>
            @key: uuid.make()
            @createdAt: time.now()
            if not @parent
                @slug: slug.make @name
                insertSlug()
            else
                Category.exists client, @parent, errw cb, (exists) =>
                    if not exists then return cb(
                        new Error "parent key '$@parent' does not exist"
                    )
                    client.get "category:$@parent:slug", errw cb, (reply) =>
                        @slug: reply.toString() + "/" + slug.make @name
                        insertSlug()
        # Step 2: insert the slug, but fail if it's already present. Add this 
        # category to its parent's collection or a root collection.
        insertSlug: => 
            client.setnx "category:slug:$@slug", @key, errw cb, (reply) =>
                if reply is 0 then return cb(
                    new Error "category with that slug already exists"
                )
                client.set "category:name:$@name", @key, errw cb, (reply) =>
                    if not @parent then addToRootSet() else addToParentSet()
        # Step 3a: indicate that this a root-level category by adding it to 
        # the root set. This occurs only if there is no parent.
        addToRootSet: =>
            client.sadd "category:root", @key, errw cb, (reply) =>
                insertFields()
        # Step 3b: add this category to its parent's set of children
        addToParentSet: =>
            client.sadd "category:$@parent:children", @key, errw cb, (reply) =>
                insertFields()
        # Step 4: persist the category's fields and add it to the 'all' set
        insertFields: => 
            model.save client, "category", @toFields(), errw cb, (reply) =>
                client.sadd "category:all", @key, errw cb, (reply) ->
                    cb null
        start()

    #
    # Lazy Initialization ----
    #

    loadChildren: (client, cb) ->
        if @children.length < 1 then return cb null
        Category.findByKeys client, @children, errw cb, (categories) =>
            @children: categories
            cb null

    loadChildrenRecursively: (client, cb) ->
        Category.loadCategories client, @categories, 0, cb

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

    @all: (client, cb) ->
        client.smembers "category:all", errw2 cb, (keys) ->
            if not keys then return cb null, null
            keys: k.toString() for k in keys
            Category.findByKeys client, keys, errw2 cb, (categories) ->
                cb null, categories

    @recursive: (client, cb) ->
        Category.root client, errw2 cb, (categories) ->
            Category.loadCategories client, categories, 0, cb

    @root: (client, cb) ->
        client.smembers "category:root", errw2 cb, (keys) ->
            if not keys then return cb null, null
            keys: k.toString() for k in keys
            Category.findByKeys client, keys, errw2 cb, (categories) ->
                cb null, categories

    #
    # Find ----
    #

    @exists: (client, key, cb) ->
        client.get "category:$key:name", errw2 cb, (reply) ->
            cb null, reply isnt null

    @findByKey: (client, key, cb) ->
        Category.findByKeys client, [key], errw2 cb, (categories) ->
            cb null, categories[0]

    @findByKeys: (client, keys, cb) ->
        # Step 1: load fields for all requested keys using a big 'mget'
        start: =>
            model.load(client, "category", @fields(), keys, (-> new Category()), 
                errw2 cb, (categories) -> 
                    loadCollections client, categories, [], cb
            )
        # Step 2: load member collections for every object returned in the 1st 
        # step. This function traverses each object via recursion.
        loadCollections: (client, categories, collector, cb) ->
            category: categories.shift()
            if not category then return cb null, collector
            client.smembers "category:$category.key:children", errw2 cb, (children) ->
                if children 
                    category.children: c.toString() for c in children
                collector.push category
                loadCollections client, categories, collector, errw2 cb, (categories) ->
                    cb null, categories
        start()

    @findByName: (client, name, cb) ->
        client.get "category:name:$name", errw2 cb, (reply) ->
           if not reply then return cb null, null
           Category.findByKey client, reply.toString(), cb

    @findByPartialName: (client, name, limit, cb) ->
        # Redis treats '*' as a wildcard, this is our only tool for searching
        client.keys "category:name:*$name*", errw2 cb, (keys) ->
            if not keys then return cb null, []
            # hopefully we won't have to split() on this in the future
            keys: keys.toString().split(" ")
            if limit > 0 and keys.length > limit
                keys: keys.slice(0, limit)
            redis.command client, "mget", keys, errw2 cb, (keys) ->
                keys: k.toString() for k in keys
                Category.findByKeys client, keys, errw2 cb, (categories) ->
                    cb null, categories

    @findBySlug: (client, slug, cb) ->
        client.get "category:slug:$slug", errw2 cb, (reply) ->
           if not reply then return cb null, null
           Category.findByKey client, reply.toString(), cb

    #
    # Private ----
    #

    @loadCategories: (client, categories, i, cb) ->
        if i >= categories.length then return cb null, categories
        category: categories[i]
        category.loadChildren client, =>
            loadCategories client, category.children, 0, errw2 cb, (x) =>
                loadCategories client, categories, i+1, errw2 cb, (categories) =>
                    cb null, categories

exports.Category: Category

