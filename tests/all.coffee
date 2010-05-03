require.paths.unshift "./support/redis-node-client/lib"

assert: require "assert"
redis:  require "redis-client"
sys:    require "sys"

# Run all tests sequentially, still haven't decided for sure whether or not 
# this is desirable, or if we should try for parallelism
runTests: (tests, callback) ->
    if tests.length < 1 then return callback()
    test: tests.shift()
    sys.puts "Running test: " + test.name
    client: redis.createClient()
    client.select 13, (err, reply) ->
        if err then assert.fail err, "select test database"
        assert.ok reply, "select test database"
        client.flushdb (err, reply) ->
            if err then assert.fail err, "flush test database"
            assert.ok reply, "flush test database"
            test client, ->
                client.close()
                runTests tests, callback

line: ->
    new Array(79).join("-")

allTests:
    require("./category_tests").categoryTests

sys.puts line()
sys.puts "Running Factz test suite of $allTests.length test(s)"
sys.puts line()
runTests allTests, ->
    sys.puts line()
    sys.puts "Passed!"
    sys.puts line()

