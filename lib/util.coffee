sys: require "sys"

global.errw: (callback, next) ->
    target: (err, reply) ->
        if err then return callback err
        next(reply)
    target

global.errw2: (callback, next) ->
    target: (err, reply) ->
        if err then return callback err, null
        next(reply)
    target

