require.paths.unshift "./support/node-discount/build/default"
require.paths.unshift "./support/redis-node-client/lib"

assert: require "assert"
redis:  require "redis-client"
sys:    require "sys"

# Run all tests sequentially, still haven't decided for sure whether or not 
# this is desirable, or if we should try for parallelism
runTests: (tests, cb) ->
    if tests.length < 1 then return cb()
    test: tests.shift()
    ds: redis.createClient()
    ds.select 13, (err, reply) ->
        if err then assert.fail err, "select test database"
        assert.ok reply, "select test database"
        ds.flushdb (err, reply) ->
            if err then assert.fail err, "flush test database"
            assert.ok reply, "flush test database"
            test ds, ->
                sys.puts " ... OK!"
                ds.close()
                runTests tests, cb

line: ->
    new Array(79).join("-")

allTests:
    [].concat(
        require("./category_tests").categoryTests()
        require("./fact_tests").factTests()
    )

sys.puts line()
sys.puts "Running Factz test suite of $allTests.length test(s)"
sys.puts line()
runTests allTests, ->
    sys.puts line()
    sys.puts "Passed!"
    sys.puts line()

