require.paths.unshift "./support/node-discount/build/default"
require.paths.unshift "./support/redis-node-client/lib"

require "../lib/async"

fs:    require "fs"
redis: require "../lib/redis"
sys:   require "sys"

Category: require("../models/category").Category
Fact:     require("../models/fact").Fact

packCategories: (categories) ->
    categories.map (category) ->
        pack: { name: category.name }
        if category.children.length > 0
            pack.children: packCategories category.children
        pack

packFacts: (facts) ->
    facts.map (fact) ->
        pack: { content: fact.content, categories: [] }
        for category in fact.categories
            pack.categories.push buildCategoryPath category
        pack

buildCategoryPath: (category) ->
    if category
        buildCategoryPath(category.parent).concat(category.name)
    else
        []

main: ->
    filename: process.argv[2]
    ds: redis.ds()
    Category.recursive ds, (err, categories) ->
        out: { categories: packCategories categories }
        Fact.all ds, (err, facts) ->
            map facts, 
                ((fact, next) ->
                    fact.loadCategories ds, (err) ->
                        if err then throw err
                        map fact.categories, 
                            ((category, next) ->
                                category.loadParentRecursively ds, (err) ->
                                    if err then throw err
                                    next category
                            ),
                            (categories) ->
                                next fact
                ), 
                (facts) ->
                    out.facts: packFacts facts
                    #sys.puts sys.inspect out, false, null
                    fs.writeFileSync filename, JSON.stringify out, "utf8"
                    sys.puts "Wrote data to: $filename"
                    ds.close()
                    process.exit()

main()

