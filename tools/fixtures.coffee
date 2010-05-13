require.paths.unshift "./support/redis-node-client/lib"

fs:    require "fs"
redis: require "../lib/redis"
sys:   require "sys"

Category: require("../models/category").Category
Fact:     require("../models/fact").Fact

level: 0

addCategories: (ds, categories, parent, cb) ->
    category = categories.shift()
    if not category then return cb()
    addCategory ds, category, parent, ->
        addCategories ds, categories, parent, ->
            cb()

addCategory: (ds, category, parent, cb) ->
    category2 = Category.make category.name
    category2.parent = parent
    category2.insert ds, (err) ->
        if err then throw err
        sys.puts "inserted $category2.slug"
        if category.children
            addCategories ds, category.children, category2.key, ->
                cb()
        else
            cb()

addFacts: (ds, facts, cb) ->
    fact = facts.shift()
    if not fact then return cb()
    addFact ds, fact, ->
        addFacts ds, facts, cb

addFact: (ds, fact, cb) ->
    start: ->
        findCategories fact.categories, [], (categories) ->
            fact2 = Fact.make fact.content
            fact2.categories = c.key for c in categories
            fact2.insert ds, (err) ->
                if err then throw err
                excerpt: fact2.excerpt()
                sys.puts "Inserted fact '$excerpt' for $categories.length categor(ies)"
                cb()
    findCategories: (paths, categories, cb) ->
        path = paths.shift()
        if not path then return cb categories
        Category.findByPath ds, path, (err, category) ->
            if err then throw err
            categories.push category
            findCategories paths, categories, cb
    start()

line: ->
    new Array(79).join("-")

main: ->
    data: fs.readFileSync "./tools/fixtures.json"
    fixtures: eval data
    ds: redis.ds()
    sys.puts line()
    addCategories ds, fixtures.categories, null, ->
        sys.puts line()
        addFacts ds, fixtures.facts, ->
            sys.puts line()
            sys.puts "DONE!"
            sys.puts line()
            process.exit()

main()

