assert: require "assert"

Category: require("../models/category").Category
Fact:     require("../models/fact").Fact

exports.factTests: -> [
    testFactInsert
    testFactInsertWithBadCategory
    testFactInsertWithNoCategories
]

testFactInsert: (client, cb) ->
    category: Category.make "science"
    category.insert client, (err) ->
        assert.ok not err
        fact: Fact.make "science is fun!"
        fact.categories.push category.key
        fact.insert client, (err) ->
            assert.ok not err
            assert.ok fact.key isnt undefined
            assert.ok fact.createdAt isnt undefined
            cb()

testFactInsertWithBadCategory: (client, cb) ->
    fact: Fact.make "science is fun!"
    fact.categories.push "bad-category-key"
    fact.insert client, (err) ->
        assert.ok err isnt null
        cb()

testFactInsertWithNoCategories: (client, cb) ->
    fact: Fact.make "science is fun!"
    fact.insert client, (err) ->
        assert.ok err isnt null
        cb()

