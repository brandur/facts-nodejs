redisclient: require "redis-client"

redisClient: null

exports.ds: ->
    if not redisClient or not redisClient.connected
        redisClient: redisclient.createClient()
        redisClient.noReconnect = true
    return redisClient

exports.command: (ds, command, args, cb) ->
    ds.sendCommand.apply ds, [ command ].concat(args, [ cb ])

