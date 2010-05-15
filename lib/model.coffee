redis: require "../lib/redis"

sys:  require "sys"

exports.remove: (ds, type, fields, keys, cb) ->
    args = makeArgs type, fields, keys
    redis.command ds, "del", args, (err, reply) ->
        cb err

exports.load: (ds, type, fields, keys, newFunc, cb) ->
    args = makeArgs type, fields, keys
    #sys.p args
    redis.command ds, "mget", args, (err, reply) ->
        if err then cb err, null
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
        cb null, objs

exports.save: (ds, type, serialized, cb) ->
    args = []
    for k, v of serialized
        if k isnt "key" and v
            args.push "$type:$serialized.key:$k"
            args.push v
    #sys.p args
    redis.command ds, "mset", args, cb

makeArgs: (type, fields, keys) ->
    args = []
    for k in keys
        for f in fields
            if typeof f is "string"
                args.push "$type:$k:$f"
            else 
                args.push "$type:$k:" + f.ds
    args

