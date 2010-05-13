assert: require "assert"

Category: require("../models/category").Category
Fact:     require("../models/fact").Fact

exports.factTests: -> [
    testFactInsert
    testFactInsertWithManyCategories
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

testFactInsertWithManyCategories: (ds, cb) ->
    fact: Fact.make "science & art are fun!"
    science: Category.make "science"
    science.insert ds, (err) ->
        assert.ok not err
        fact.categories.push science.key
        art: Category.make "art"
        art.insert ds, (err) ->
            assert.ok not err
            fact.categories.push art.key
            fact.insert ds, (err) ->
                assert.ok not err
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

