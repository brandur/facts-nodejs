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
    # Persistence ----
    #

    insert: (client, cb) ->
        # Step 1: initialize members for insert and save fields
        start: =>
            @key: uuid.make()
            @createdAt: time.now()
            if @categories.length < 1 then return cb(
                new Error "a fact must belong to at least one category"
            )
            model.save client, "category", @toFields(), errw cb, (reply) =>
                addCategories @categories
        # Step 2: add each category to this fact's set, and add the fact to 
        # that category's facts set. This function calls itself recursively in 
        # order to add all categories.
        addCategories: (categories) =>
            category = categories.shift()
            if not category then return cb null
            Category.exists client, category, errw cb, (exists) =>
                if not exists then return cb(
                    new Error "category key '$category' does not exist"
                )
                client.sadd "fact:$@key:categories", category, 
                    errw cb, (reply) =>
                        client.sadd "category:$category:facts", @key, 
                            errw cb, (reply) =>
                                addCategories categories
        start()

    #
    # Serialization ----
    #

    @fields: ->
        [
            "content"
            { obj: "createdAt", datastore: "created_at" }
        ]

    toFields: ->
        {
            key: @key
            content: @content
            created_at: @createdAt
        }

    toJSON: ->
        o: @toFields()
        o.categories: @categories
        o

exports.Fact: Fact

