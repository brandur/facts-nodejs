redis: require "../lib/redis"

sys:  require "sys"

exports.load: (ds, type, fields, keys, newFunc, callback) ->
    args = []
    for k in keys
        for f in fields
            if typeof f is "string"
                args.push "$type:$k:$f"
            else 
                args.push "$type:$k:" + f.datastore
    redis.command ds, "mget", args, (err, reply) ->
        if err then callback err, null
        objs: []
        j: 0
        for i in [0...keys.length]
            o: newFunc()
            o.key: keys[i]
            for k in [0...fields.length]
                field: if typeof fields[k] is "string" 
                    fields[k]
                else
                    fields[k].obj
                o[field] = reply[j]?.toString()
                j++
            objs.push o
        callback null, objs

exports.save: (ds, type, serialized, callback) ->
    args = []
    for k, v of serialized
        #sys.puts "k:" + k + " v:" + v
        if k isnt "key" and v
            args.push "$type:$serialized.key:$k"
            args.push v
    redis.command ds, "mset", args, callback

