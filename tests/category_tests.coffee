assert: require "assert"

Category: require("../models/category").Category

# @todo: put in an actual BDD test suite
describe: require("sys").puts
it:       (s) -> require("sys").print "    $s"

exports.categoryTests: -> [
    testCategoryExists
    testCategoryInsert
    testCategoryInsertDuplicate
    testCategoryInsertWithParent
    testCategoryInsertWithBadParent
]

testCategoryExists: (ds, cb) ->
    describe "Category.exists"
    it "should test existence correctly"
    Category.exists ds, "bad-category-key", (err, exists) ->
        assert.ok exists is false
        category = Category.make "science"
        category.insert ds, (err) ->
            assert.ok not err
            Category.exists ds, category.key, (err, exists) ->
                assert.ok exists
                cb()

testCategoryInsert: (ds, cb) ->
    describe "Category.insert"
    it "should create correctly given good parameters"
    category = Category.make "science"
    assert.ok category.parent is undefined
    category.insert ds, (err) ->
        assert.ok not err
        assert.ok category.key isnt undefined
        assert.ok category.createdAt isnt undefined
        assert.ok category.slug isnt undefined
        cb()

testCategoryInsertDuplicate: (ds, cb) ->
    it "should fail if we insert a duplicate slug"
    category = Category.make "science"
    category.insert ds, (err) ->
        assert.ok not err
        category2 = Category.make "science"
        category2.insert ds, (err) ->
            assert.ok err isnt null
            cb()

testCategoryInsertWithParent: (ds, cb) ->
    it "should create correctly given a parent category"
    parent = Category.make "science"
    parent.insert ds, (err) ->
        assert.ok not err
        category = Category.make "biology"
        category.parent = parent.key
        category.insert ds, (err) ->
            assert.ok not err
            cb()

testCategoryInsertWithBadParent: (ds, cb) ->
    it "should fail given a non-existent parent"
    category = Category.make "orphaned"
    category.parent = "bad-parent-key"
    category.insert ds, (err) ->
        assert.ok err isnt null
        cb()

