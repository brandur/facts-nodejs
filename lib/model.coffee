redis: require "../lib/redis"

sys:  require "sys"

exports.load: (client, type, fields, keys, newFunc, callback) ->
    args = []
    for k in keys
        for f in fields
            args.push "$type:$k:$f"
    redis.command client, "mget", args, (err, reply) ->
        if err then callback err, null
        objs = []
        j = 0
        for i in [0...keys.length]
            o: newFunc()
            o.key = keys[i]
            for k in [0...fields.length]
                o[fields[k]] = reply[j]?.toString()
                j++
            objs.push o
        callback null, objs

exports.save: (client, type, fields, callback) ->
    args = []
    for k, v of fields
        #sys.puts "k:" + k + " v:" + v
        if k isnt "key" and v
            args.push "$type:$fields.key:$k"
            args.push v
    redis.command client, "mset", args, callback

