md:    require "markdown"
model: require "../lib/model"
redis: require "../lib/redis"
sys:   require "sys"
time:  require "../lib/time"
uuid:  require "../lib/uuid"

Category: require("../models/category").Category

class Fact

    #
    # Initialization ----
    #

    constructor: ->
        @categories: []

    @make: (content) ->
        fact: new Fact()
        fact.content: content
        fact 

    #
    # Properties ----
    #

    contentHtml: ->
        md.parse @content

    excerpt: ->
        @content[0...20] + " ..."

    #
    # Persistence ----
    #

    insert: (ds, cb) ->
        # S1: initialize members for insert and save fields
        start: =>
            @key: uuid.make()
            @createdAt: time.now()
            if @categories.length < 1 then return cb(
                new Error "a fact must belong to at least one category"
            )
            model.save ds, "fact", @toFields(), errw cb, (reply) =>
                addCategories @categories[0...@categories.length]
        # S2: add each category to this fact's set, and add the fact to that 
        # category's facts set. This function calls itself recursively in 
        # order to add all categories.
        addCategories: (categories) =>
            category = categories.shift()
            if not category then return cb null
            Category.exists ds, category, errw cb, (exists) =>
                if not exists then return cb(
                    new Error "category key '$category' does not exist"
                )
                ds.sadd "fact:$@key:categories", category, errw cb, (reply) =>
                    ds.sadd "category:$category:facts", @key, 
                        errw cb, (reply) =>
                            addCategories categories
        start()

    destroy: (ds, cb) ->
        # S1: start recursive category removal
        start: =>
            if not @key then return cb new Error "need primary key to destroy"
            removeCategories @categories
        # S2: remove this fact from each of its categories' sets, then delete 
        # each of its fields
        removeCategories: (categories) =>
            category = categories.shift()
            if not category 
                return model.destroy ds, "fact", Fact.members(), [@key], cb
            ds.srem "category:$category:facts", @key, errw cb, (reply) =>
                removeCategories categories
        start()

    #
    # Serialization ----
    #

    @fields: ->
        [
            "content"
            { obj: "createdAt", ds: "created_at" }
        ]

    @members: ->
        @fields().concat ["categories"]

    toFields: ->
        {
            key: @key
            content: @content
            created_at: @createdAt
        }

    toJSON: ->
        obj: @toFields()
        obj.categories: @categories
        obj.excerpt: @excerpt()
        obj

    #
    # Find ----
    #

    @exists: (ds, key, cb) ->
        ds.exists "fact:$key:content", errw2 cb, (reply) ->
            cb null, reply is 1

    @findByKey: (ds, key, cb) ->
        Fact.findByKeys ds, [key], errw2 cb, (facts) ->
            cb null, facts[0]

    @findByKeys: (ds, keys, cb) ->
        # S1: load fields for all requested keys using a big 'mget'
        start: =>
            model.load ds, "fact", @fields(), keys, 
                -> new Fact(), 
                errw2 cb, (facts) -> 
                    loadCollections ds, facts, [], cb
        # S2: load member collections for every object returned in the 1st 
        # step. This function traverses each object via recursion.
        loadCollections: (ds, facts, collector, cb) ->
            fact: facts.shift()
            if not fact then return cb null, collector
            ds.smembers "fact:$fact.key:categories", errw2 cb, (categories) ->
                if categories
                    fact.categories: c.toString() for c in categories
                collector.push fact
                loadCollections ds, facts, collector, errw2 cb, (facts) ->
                    cb null, facts
        start()

    @move: (ds, key, oldCat, newCat, cb) ->
        start: ->
            Fact.exists ds, key, errw2 cb, (exists) ->
                if not exists 
                    return cb new Error "fact $key does not exist"
                Category.exists ds, oldCat, errw2 cb, (exists) ->
                    if not exists 
                        return cb new Error "category $oldCat does not exist"
                    Category.exists ds, newCat, errw2 cb, (exists) ->
                        if not exists 
                            return cb new Error "category $newCat does not exist"
                        move()
        move: ->
            ds.sadd "fact:$key:categories", newCat, errw2 cb, (reply) ->
                ds.sadd "category:$newCat:facts", key, errw2 cb, (reply) ->
                    ds.srem "fact:$key:categories", oldCat, errw2 cb, (reply) ->
                        ds.srem "category:$oldCat:facts", key, errw2 cb, (reply) ->
                            cb null
        start()

    #
    # Private ----
    #

    @sort: (facts) ->
        facts.sort (a, b) ->
            a.createdAt - b.createdAt

exports.Fact: Fact

