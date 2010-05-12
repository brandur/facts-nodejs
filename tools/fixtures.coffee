require.paths.unshift "./support/redis-node-client/lib"

fs:    require "fs"
redis: require "../lib/redis"
sys:   require "sys"

Category: require("../models/category").Category

level: 0

addCategories: (ds, categories, parent, callback) ->
    category = categories.shift()
    if not category then return callback()
    addCategory ds, category, parent, =>
        addCategories ds, categories, parent, =>
            callback()

addCategory: (ds, category, parent, callback) ->
    category2 = Category.make category.name
    category2.parent = parent
    category2.insert ds, (err) =>
        if err then throw err
        sys.puts "inserted $category2.slug"
        if category.children
            addCategories ds, category.children, category2.key, =>
                callback()
        else
            callback()

line: ->
    new Array(79).join("-")

main: ->
    data: fs.readFileSync "./tools/fixtures.json"
    fixtures: eval data
    ds: redis.ds()
    sys.puts line()
    addCategories ds, fixtures.categories, null, ->
        sys.puts "DONE!"
        sys.puts line()
        process.exit()

main()

