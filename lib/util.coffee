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

global.filter: (array, filterFunc, next) ->
    counter: array.length
    valid: new Array array.length
    array.forEach (item, index) ->
        filterFunc item, (result) ->
            valid[index] = result
            counter--
            if counter <= 0
                newArray: []
                array.forEach (item, index) ->
                    if valid[index]
                        newArray.push item
                next newArray

global.map: (array, mapFunc, next) ->
    counter: array.length
    newArray: new Array array.length
    array.forEach (item, index) ->
        mapFunc item, (result) ->
            newArray[index] = result
            counter--
            if counter <= 0
                next newArray

global.sanitize: (str) ->
    # Remove all HTML
    str = str.replace(/<[^>]*>/g, "")
    # No carriage returns allowed in case they are used to attack Redis
    str = str.replace(/\r/g, "")
    str.trim()

