sys: require "sys"

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

global.forEach: (array, forEachFunc, next) ->
    counter: array.length
    array.forEach (item, index) ->
        forEachFunc item, ->
            counter--
            if counter <= 0
                next()

global.map: (array, mapFunc, next) ->
    counter: array.length
    newArray: new Array array.length
    array.forEach (item, index) ->
        mapFunc item, (result) ->
            newArray[index] = result
            counter--
            if counter <= 0
                next newArray

