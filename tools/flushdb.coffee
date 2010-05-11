require.paths.unshift "./support/redis-node-client/lib"

redis: require "../lib/redis"
sys:   require "sys"

client: redis.client()
client.flushdb (err, reply) =>
    if err then throw err
    sys.puts "Flushed the datastore!"
    process.exit()

