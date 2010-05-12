assert: require "assert"

Category: require("../models/category").Category

exports.categoryTests: -> [
    testCategoryInsert
    testCategoryInsertDuplicate
    testCategoryExists
    testCategoryInsertWithParent
    testCategoryInsertWithBadParent
]

testCategoryExists: (ds, cb) ->
    Category.exists ds, "bad-category-key", (err, exists) ->
        assert.ok exists is false
        category = Category.make "science"
        category.insert ds, (err) ->
            assert.ok not err
            Category.exists ds, category.key, (err, exists) ->
                assert.ok exists
                cb()

testCategoryInsert: (ds, cb) ->
    category = Category.make "science"
    assert.ok category.parent is undefined
    category.insert ds, (err) ->
        assert.ok not err
        assert.ok category.key isnt undefined
        assert.ok category.createdAt isnt undefined
        assert.ok category.slug isnt undefined
        cb()

testCategoryInsertDuplicate: (ds, cb) ->
    category = Category.make "science"
    category.insert ds, (err) ->
        assert.ok not err
        category2 = Category.make "science"
        category2.insert ds, (err) ->
            assert.ok err isnt null
            cb()

testCategoryInsertWithParent: (ds, cb) ->
    parent = Category.make "science"
    parent.insert ds, (err) ->
        assert.ok not err
        category = Category.make "biology"
        category.parent = parent.key
        category.insert ds, (err) ->
            assert.ok not err
            cb()

testCategoryInsertWithBadParent: (ds, cb) ->
    category = Category.make "orphaned"
    category.parent = "bad-parent-key"
    category.insert ds, (err) ->
        assert.ok err isnt null
        cb()

