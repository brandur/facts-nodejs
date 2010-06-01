assert: require "assert"
sys:    require "sys"

Category: require("../models/category").Category
Fact:     require("../models/fact").Fact

# @todo: put in an actual BDD test suite
describe: require("sys").puts
it:       (s) -> require("sys").print "    $s"

exports.factTests: -> [
    testFactContentHtml
    testFactInsert
    testFactInsertWithManyCategories
    testFactInsertWithBadCategory
    testFactInsertWithNoCategories
    testFactDestroy
    testFactFindByKeys
    testFactFindByKey
    testFactMove
]

testFactContentHtml: (ds, cb) ->
    describe "Fact.contentHtml"
    it "should format the content field to HTML"
    fact: Fact.make "some fact with *emphasized content*"
    assert.ok fact.contentHtml().indexOf("<em>emphasized content</em>") isnt  -1
    cb()

testFactFindByKey: (ds, cb) ->
    describe "Fact.findByKey"
    it "should find a fact given its primary key"
    category: Category.make "science"
    category.insert ds, (err) ->
        assert.ok not err
        fact: Fact.make "science is fun!"
        fact.categories.push category.key
        fact.insert ds, (err) ->
            assert.ok not err
            Fact.findByKey ds, fact.key, (err, fact2) ->
                assert.ok not err
                assert.ok fact2.name is fact.name
                cb()

testFactFindByKeys: (ds, cb) ->
    describe "Fact.findByKeys"
    it "should find many facts given many primary keys"
    category: Category.make "science"
    category.insert ds, (err) ->
        assert.ok not err
        fact: Fact.make "science is fun!"
        fact.categories.push category.key
        fact.insert ds, (err) ->
            assert.ok not err
            Fact.findByKeys ds, [fact.key], (err, facts) ->
                assert.ok not err
                assert.ok facts.length is 1
                assert.ok facts[0].name is fact.name
                cb()

testFactInsert: (ds, cb) ->
    describe "Fact.insert"
    it "should create correctly given good parameters"
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
    it "should create correctly given multiple categories"
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
    it "should fail given a non-existent category"
    fact: Fact.make "science is fun!"
    fact.categories.push "bad-category-key"
    fact.insert ds, (err) ->
        assert.ok err isnt null
        cb()

testFactInsertWithNoCategories: (ds, cb) ->
    it "should fail given no category"
    fact: Fact.make "science is fun!"
    fact.insert ds, (err) ->
        assert.ok err isnt null
        cb()

testFactDestroy: (ds, cb) ->
    describe "Fact.destroy"
    it "should remove all traces of the destroyed fact"
    category: Category.make "science"
    category.insert ds, (err) ->
        assert.ok not err
        fact: Fact.make "science is fun!"
        fact.categories.push category.key
        fact.insert ds, (err) ->
            assert.ok not err
            fact.destroy ds, (err) ->
                assert.ok not err
                ds.keys "fact:*", (err, reply) ->
                    assert.ok not err and not reply
                    ds.smembers "category:$category.key:facts", (err, reply) ->
                        assert.ok not err and not reply
                        cb()

testFactMove: (ds, cb) ->
    describe "Fact.move"
    it "should move a fact from one category to another"
    science: Category.make "science"
    science.insert ds, (err) ->
        assert.ok not err
        math: Category.make "math"
        math.insert ds, (err) ->
            assert.ok not err
            fact: Fact.make "Pi is 3.14"
            fact.categories.push science.key
            fact.insert ds, (err) ->
                assert.ok not err
                Fact.move ds, fact.key, science.key, math.key, (err) ->
                    assert.ok not err
                    Fact.findByKey ds, fact.key, (err, fact) ->
                        assert.ok not err
                        assert.ok fact.categories.length is 1
                        assert.ok fact.categories[0] is math.key
                        Category.findByKey ds, science.key, (err, science) ->
                            assert.ok not err
                            assert.ok science.facts.length is 0
                            Category.findByKey ds, math.key, (err, math) ->
                                assert.ok not err
                                assert.ok math.facts.length is 1
                                assert.ok math.facts[0] is fact.key
                                cb()

