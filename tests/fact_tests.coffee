assert: require "assert"

Category: require("../models/category").Category
Fact:     require("../models/fact").Fact

exports.factTests: -> [
    testFactInsert
    testFactInsertWithBadCategory
    testFactInsertWithNoCategories
]

testFactInsert: (ds, cb) ->
    category: Category.make "science"
    category.insert ds, (err) ->
        assert.ok not err
        fact: Fact.make "science is fun!"
        fact.categories.push category.key
        fact.insert ds, (err) ->
            assert.ok not err
            assert.ok fact.key isnt undefined
            assert.ok fact.createdAt isnt undefined
            cb()

testFactInsertWithBadCategory: (ds, cb) ->
    fact: Fact.make "science is fun!"
    fact.categories.push "bad-category-key"
    fact.insert ds, (err) ->
        assert.ok err isnt null
        cb()

testFactInsertWithNoCategories: (ds, cb) ->
    fact: Fact.make "science is fun!"
    fact.insert ds, (err) ->
        assert.ok err isnt null
        cb()

