redisclient: require "redis-client"

redisClient: null

exports.client: ->
    if not redisClient or not redisClient.connected
        redisClient: redisclient.createClient()
        redisClient.noReconnect = true
    return redisClient

exports.command: (client, command, args, callback) ->
    client.sendCommand.apply client, [ command ].concat(args, [ callback ])

