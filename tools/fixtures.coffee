require.paths.unshift "./support/redis-node-client/lib"

fs:    require "fs"
redis: require "../lib/redis"
sys:   require "sys"

Category: require("../models/category").Category

level: 0

addCategories: (client, categories, parent, callback) ->
    if categories.length < 1 then return callback()
    category = categories[0]
    addCategory client, category, parent, () =>
        addCategories client, categories[1...categories.length], parent, () =>
            callback()

addCategory: (client, category, parent, callback) ->
    category2 = Category.make category.name
    category2.parent = parent
    category2.insert client, (err) =>
        if err then throw err
        sys.puts "inserted $category2.slug"
        if category.children
            addCategories client, category.children, category2.key, () =>
                callback()
        else
            callback()

line: ->
    new Array(79).join("-")

main: ->
    data: fs.readFileSync "./tools/fixtures.json"
    fixtures: eval data
    client: redis.client()
    sys.puts line()
    addCategories client, fixtures.categories, null, () ->
        sys.puts "DONE!"
        sys.puts line()
        process.exit()

main()

