redis: require "../lib/redis"

sys:  require "sys"

exports.save: (client, type, fields, callback) ->
    args = []
    for k, v of fields
        sys.puts "k:" + k + " v:" + v
        if k isnt "key" and v isnt null
            args.push [type, fields.key, k].join(":")
            args.push v
    redis.command client, "mset", args, callback

