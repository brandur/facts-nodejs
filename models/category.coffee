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

    insert: (ds, cb) ->
        # S1: initialize members for insert and generate an appropriate slug
        start: =>
            @key: uuid.make()
            @createdAt: time.now()
            if not @parent
                @slug: slug.make @name
                insertSlug()
            else
                Category.exists ds, @parent, errw cb, (exists) =>
                    if not exists then return cb(
                        new Error "parent key '$@parent' does not exist"
                    )
                    ds.get "category:$@parent:slug", errw cb, (reply) =>
                        @slug: reply.toString() + "/" + slug.make @name
                        insertSlug()
        # S2: insert the slug, but fail if it's already present. Add this 
        # category to its parent's collection or a root collection.
        insertSlug: => 
            ds.setnx "category:slug:$@slug", @key, errw cb, (reply) =>
                if reply is 0 then return cb(
                    new Error "category with that slug already exists"
                )
                ds.set "category:name:$@name", @key, errw cb, (reply) =>
                    if not @parent then addToRootSet() else addToParentSet()
        # S3a: indicate that this a root-level category by adding it to the 
        # root set. This occurs only if there is no parent.
        addToRootSet: =>
            ds.sadd "category:root", @key, errw cb, (reply) =>
                insertFields()
        # S3b: add this category to its parent's set of children
        addToParentSet: =>
            ds.sadd "category:$@parent:children", @key, errw cb, (reply) =>
                insertFields()
        # S4: persist the category's fields and add it to the 'all' set
        insertFields: => 
            model.save ds, "category", @toFields(), errw cb, (reply) =>
                ds.sadd "category:all", @key, errw cb, (reply) ->
                    cb null
        start()

    #
    # Lazy Initialization ----
    #

    loadChildren: (ds, cb) ->
        if @children.length < 1 then return cb null
        Category.findByKeys ds, @children, errw cb, (categories) =>
            @children: categories
            cb null

    loadChildrenRecursively: (ds, cb) ->
        Category.loadCategories ds, @categories, 0, cb

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
        obj: @toFields()
        obj.children: @children
        obj

    #
    # Sets ----
    #

    @all: (ds, cb) ->
        ds.smembers "category:all", errw2 cb, (keys) ->
            if not keys then return cb null, null
            keys: k.toString() for k in keys
            Category.findByKeys ds, keys, errw2 cb, (categories) ->
                cb null, categories

    @recursive: (ds, cb) ->
        Category.root ds, errw2 cb, (categories) ->
            Category.loadCategories ds, categories, 0, cb

    @root: (ds, cb) ->
        ds.smembers "category:root", errw2 cb, (keys) ->
            if not keys then return cb null, null
            keys: k.toString() for k in keys
            Category.findByKeys ds, keys, errw2 cb, (categories) ->
                cb null, categories

    #
    # Find ----
    #

    @exists: (ds, key, cb) ->
        ds.get "category:$key:name", errw2 cb, (reply) ->
            cb null, reply isnt null

    @findByKey: (ds, key, cb) ->
        Category.findByKeys ds, [key], errw2 cb, (categories) ->
            cb null, categories[0]

    @findByKeys: (ds, keys, cb) ->
        # S1: load fields for all requested keys using a big 'mget'
        start: =>
            model.load ds, "category", @fields(), keys, 
                -> new Category(), 
                errw2 cb, (categories) -> 
                    loadCollections ds, categories, [], cb
        # S2: load member collections for every object returned in the 1st 
        # step. This function traverses each object via recursion.
        loadCollections: (ds, categories, collector, cb) ->
            category: categories.shift()
            if not category then return cb null, collector
            ds.smembers "category:$category.key:children", 
                errw2 cb, (children) ->
                    if children 
                        category.children: c.toString() for c in children
                    collector.push category
                    loadCollections ds, categories, collector, 
                        errw2 cb, (categories) ->
                            cb null, categories
        start()

    @findByName: (ds, name, cb) ->
        ds.get "category:name:$name", errw2 cb, (reply) ->
           if not reply then return cb null, null
           Category.findByKey ds, reply.toString(), cb

    @findByPartialName: (ds, name, limit, cb) ->
        # Redis treats '*' as a wildcard, this is our only tool for searching
        ds.keys "category:name:*$name*", errw2 cb, (keys) ->
            if not keys then return cb null, []
            # hopefully we won't have to split() on this in the future
            keys: keys.toString().split(" ")
            if limit > 0 and keys.length > limit
                keys: keys.slice(0, limit)
            redis.command ds, "mget", keys, errw2 cb, (keys) ->
                keys: k.toString() for k in keys
                Category.findByKeys ds, keys, errw2 cb, (categories) ->
                    cb null, categories

    @findBySlug: (ds, slug, cb) ->
        ds.get "category:slug:$slug", errw2 cb, (reply) ->
           if not reply then return cb null, null
           Category.findByKey ds, reply.toString(), cb

    #
    # Private ----
    #

    @loadCategories: (ds, categories, i, cb) ->
        if i >= categories.length then return cb null, categories
        category: categories[i]
        category.loadChildren ds, =>
            loadCategories ds, category.children, 0, errw2 cb, (x) =>
                loadCategories ds, categories, i+1, 
                    errw2 cb, (categories) =>
                        cb null, categories

exports.Category: Category

