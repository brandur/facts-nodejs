require.paths.unshift "./support/node-discount/build/default"
require.paths.unshift "./support/redis-node-client/lib"

require "../lib/async"

fs:    require "fs"
redis: require "../lib/redis"
sys:   require "sys"

Category: require("../models/category").Category
Fact:     require("../models/fact").Fact

addCategories: (ds, categories, parent, next) ->
    map categories, 
        ((category, next) ->
            addCategory ds, category, parent, ->
                next category
        ), 
        (categories) ->
            next()

addCategory: (ds, category, parent, cb) ->
    category2 = Category.make category.name
    category2.parent = parent
    category2.insert ds, (err) ->
        if err then throw err
        sys.puts "Inserted $category2.slug"
        if category.children
            addCategories ds, category.children, category2.key, ->
                cb()
        else
            cb()

addFacts: (ds, facts, next) ->
    map facts, 
        ((fact, next) ->
            addFact ds, fact, ->
                next fact
        ), 
        (facts) ->
            next()

addFact: (ds, fact, next) ->
    start: ->
        findCategories fact.categories, (categories) ->
            fact2 = Fact.make fact.content
            fact2.categories = c.key for c in categories
            fact2.insert ds, (err) ->
                if err then throw err
                excerpt: fact2.excerpt()
                sys.puts "Inserted fact '$excerpt' for $categories.length categor(ies)"
                next()
    findCategories: (paths, next) ->
        map paths, 
            ((path, next) ->
                if not path then throw new Error "null path"
                Category.findByPath ds, path, (err, category) ->
                    if err then throw err else next category
            ), 
            (categories) ->
                next categories
    start()

line: ->
    new Array(79).join("-")

main: ->
    filename: process.argv[2]
    sys.puts "Reading data from: $filename"
    data: fs.readFileSync filename, "utf8"
    fixtures: JSON.parse data
    ds: redis.ds()
    sys.puts line()
    addCategories ds, fixtures.categories, null, ->
        sys.puts line()
        addFacts ds, fixtures.facts, ->
            sys.puts line()
            sys.puts "DONE!"
            sys.puts line()
            ds.close()
            process.exit()

main()

