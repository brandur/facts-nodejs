sys: require "sys"

global.errWrap: (callback, next) ->
    target: (err, reply) ->
        if err then return callback err
        next(reply)
    target

global.errWrap2: (callback, next) ->
    target: (err, reply) ->
        if err then return callback err, null
        next(reply)
    target

