assert: require "assert"

Category: require("../models/category").Category

testCategoryExists: (client, callback) ->
    Category.exists client, "bad-category-key", (err, exists) ->
        assert.ok exists is false
        category = Category.make "science"
        category.insert client, (err) ->
            assert.ok not err
            Category.exists client, category.key, (err, exists) ->
                assert.ok exists
                callback()

testCategoryInsert: (client, callback) ->
    category = Category.make "science"
    assert.ok category.slug isnt undefined
    assert.ok category.parent is undefined
    category.insert client, (err) ->
        assert.ok not err
        assert.ok category.key isnt undefined
        callback()

testCategoryInsertDuplicate: (client, callback) ->
    category = Category.make "science"
    category.insert client, (err) ->
        assert.ok not err
        category2 = Category.make "science"
        category2.insert client, (err) ->
            assert.ok err isnt null
            callback()

testCategoryInsertWithParent: (client, callback) ->
    parent = Category.make "science"
    parent.insert client, (err) ->
        assert.ok not err
        category = Category.make "biology"
        category.parent = parent.key
        category.insert client, (err) ->
            assert.ok not err
            callback()

testCategoryInsertWithBadParent: (client, callback) ->
    category = Category.make "orphaned"
    category.parent = "bad-parent-key"
    category.insert client, (err) ->
        assert.ok err isnt null
        callback()

exports.categoryTests: [
    testCategoryInsert
    testCategoryInsertDuplicate
    testCategoryExists
    testCategoryInsertWithParent
    testCategoryInsertWithBadParent
]

