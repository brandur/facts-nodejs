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
        @facts: []

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
                ds.sadd "category:name:$@name", @key, errw cb, (reply) =>
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
            Category.sort categories
            @children: categories
            cb null

    loadChildrenRecursively: (ds, cb) ->
        Category.loadCategories ds, @categories, 0, cb

    loadChildrenWithFacts: (ds, cb) ->
        start: =>
            @loadChildren ds, (err) =>
                if err then return cb err
                loadFacts @children[0...@children.length]
        loadFacts: (categories) ->
            category = categories.shift()
            if not category then return cb null
            category.loadFacts ds, (err) ->
                if err then return cb err
                loadFacts categories
        start()

    loadFacts: (ds, cb) ->
        if @facts.length < 1 then return cb null
        # @todo: any way to move this out of here?
        Fact: require("../models/fact").Fact
        Fact.findByKeys ds, @facts, errw cb, (facts) =>
            Fact.sort facts
            @facts: facts
            cb null

    loadParent: (ds, cb) ->
        if not @parent then return cb null
        Category.findByKey ds, @parent, errw cb, (parent) =>
            @parent: parent
            cb null

    loadParentRecursively: (ds, cb) ->
        if not @parent then return cb null
        @loadParent ds, (err) =>
            if err then return cb err
            @parent.loadParentRecursively ds, cb

    #
    # Serialization ----
    #

    @fields: ->
        [ 
            "name"
            "slug"
            "parent"
            { obj: "createdAt", ds: "created_at" }
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
        obj.facts: @facts
        obj

    #
    # Sets ----
    #

    @all: (ds, cb) ->
        ds.smembers "category:all", errw2 cb, (keys) ->
            if not keys then return cb null, null
            keys: k.toString() for k in keys
            Category.findByKeys ds, keys, errw2 cb, (categories) ->
                Category.sort categories
                cb null, categories

    @recursive: (ds, cb) ->
        Category.root ds, errw2 cb, (categories) ->
            Category.loadCategories ds, categories, 0, 
                errw2 cb, (categories) ->
                    Category.sort categories
                    cb null, categories

    @root: (ds, cb) ->
        ds.smembers "category:root", errw2 cb, (keys) ->
            if not keys then return cb null, null
            keys: k.toString() for k in keys
            Category.findByKeys ds, keys, errw2 cb, (categories) ->
                Category.sort categories
                cb null, categories

    #
    # Find ----
    #

    @exists: (ds, key, cb) ->
        ds.exists "category:$key:name", errw2 cb, (reply) ->
            cb null, reply is 1

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
            # Load child categories
            ds.smembers "category:$category.key:children", 
                errw2 cb, (children) ->
                    if children 
                        category.children: c.toString() for c in children
                    # Load facts
                    ds.smembers "category:$category.key:facts", 
                        errw2 cb, (facts) ->
                            if facts
                                category.facts: c.toString() for c in facts
                            collector.push category
                            loadCollections ds, categories, collector, 
                                errw2 cb, (categories) ->
                                    cb null, categories
        start()

    # @todo: possibly get rid of this
    @findByName: (ds, name, parent, cb) ->
        ds.smembers "category:name:$name", errw2 cb, (keys) ->
            if not keys then return cb null, null
            keys: keys.toString() for k in keys
            Category.findByKeys ds, keys, errw2 cb, (categories) ->
                for category in categories
                    if category.parent is parent or 
                        (not category.parent and not parent)
                            return cb null, category
                cb null, null

    @findByPartialName: (ds, name, limit, cb) ->
        # Redis treats '*' as a wildcard, this is our only tool for searching
        ds.keys "category:name:*$name*", errw2 cb, (keys) ->
            if not keys then return cb null, []
            # hopefully we won't have to split() on this in the future
            keys: keys.toString().split(" ")
            if limit > 0 and keys.length > limit
                keys: keys.slice 0, limit
            redis.command ds, "sunion", keys, errw2 cb, (keys) ->
                keys: k.toString() for k in keys
                Category.findByKeys ds, keys, errw2 cb, (categories) ->
                    cb null, categories

    # Finds a category by its name path (every category can be represented 
    # uniquely using its name, and the name of each of its parents). _path_ 
    # should be given as an array of names starting at the root.
    @findByPath: (ds, fullPath, cb) ->
        start: ->
            path = fullPath[0...fullPath.length]
            root = path.shift()
            Category.findByName ds, root, null, errw2 cb, (category) ->
                findDescendant path, category, cb
        findDescendant: (path, category, cb) ->
            if path.length < 1 then return cb null, category
            next = path.shift()
            category.loadChildren ds, errw cb, () ->
                if category.children
                    for c in category.children
                        if c.name == next
                            return findDescendant path, c, cb
                return cb new Error "no category at path: $fullPath", null
        start()

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
        category.loadChildren ds, ->
            Category.loadCategories ds, category.children, 0, errw2 cb, (x) ->
                Category.loadCategories ds, categories, i+1, 
                    errw2 cb, (categories) ->
                        cb null, categories

    @sort: (categories) ->
        categories.sort (a, b) ->
            aName = a.name.toLowerCase()
            bName = b.name.toLowerCase()
            if aName > bName then 1 else 
                if aName is bName then 0 else -1

exports.Category: Category

