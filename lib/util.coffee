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

global.sanitize: (str) ->
    # Remove all HTML
    str = str.replace(/<[^>]*>/g, "")
    # No carriage returns allowed in case they are used to attack Redis
    str = str.replace(/\r/g, "")
    trim str

global.trim: (str) ->
    isWhitespace: (c) ->
        c is " " or c is "\n" or c is "\t"
    l: 0
    r: str.length - 1
    l++ while l < str.length and isWhitespace str[l]
    r-- while r > l and isWhitespace str[r]
    str.substring l, r + 1

