require.paths.unshift "./support/redis-node-client/lib"

redis: require "../lib/redis"
sys:   require "sys"

ds: redis.ds()
ds.flushdb (err, reply) =>
    if err then throw err
    sys.puts "Flushed the datastore!"
    ds.close()
    process.exit()

