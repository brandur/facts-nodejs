assert: require "assert"

Category: require("../models/category").Category

exports.categoryTests: -> [
    testCategoryInsert
    testCategoryInsertDuplicate
    testCategoryExists
    testCategoryInsertWithParent
    testCategoryInsertWithBadParent
]

testCategoryExists: (client, cb) ->
    Category.exists client, "bad-category-key", (err, exists) ->
        assert.ok exists is false
        category = Category.make "science"
        category.insert client, (err) ->
            assert.ok not err
            Category.exists client, category.key, (err, exists) ->
                assert.ok exists
                cb()

testCategoryInsert: (client, cb) ->
    category = Category.make "science"
    assert.ok category.parent is undefined
    category.insert client, (err) ->
        assert.ok not err
        assert.ok category.key isnt undefined
        assert.ok category.createdAt isnt undefined
        assert.ok category.slug isnt undefined
        cb()

testCategoryInsertDuplicate: (client, cb) ->
    category = Category.make "science"
    category.insert client, (err) ->
        assert.ok not err
        category2 = Category.make "science"
        category2.insert client, (err) ->
            assert.ok err isnt null
            cb()

testCategoryInsertWithParent: (client, cb) ->
    parent = Category.make "science"
    parent.insert client, (err) ->
        assert.ok not err
        category = Category.make "biology"
        category.parent = parent.key
        category.insert client, (err) ->
            assert.ok not err
            cb()

testCategoryInsertWithBadParent: (client, cb) ->
    category = Category.make "orphaned"
    category.parent = "bad-parent-key"
    category.insert client, (err) ->
        assert.ok err isnt null
        cb()

