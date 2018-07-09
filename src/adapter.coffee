#
# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license.
#
# Microsoft Bot Framework: http://botframework.com
#
# Bot Builder SDK Github:
# https://github.com/Microsoft/BotBuilder
#

Util = require 'util'
Timers = require 'timers'

BotBuilder = require 'botbuilder'
{ Robot, Adapter, TextMessage, User } = require 'hubot'
Middleware = require './adapter-middleware'
MicrosoftTeamsMiddleware = require './msteams-middleware'

LogPrefix = "hubot-botframework-adapter:"

class BotFrameworkAdapter extends Adapter
    constructor: (robot) ->
        super robot
        @appId = process.env.BOTBUILDER_APP_ID
        @appPassword = process.env.BOTBUILDER_APP_PASSWORD
        @endpoint = process.env.BOTBUILDER_ENDPOINT || "/api/messages"
        robot.logger.info "#{LogPrefix} Adapter loaded. Using appId #{@appId}"

        # *** Adding my own variables
        # Adding Hubot admins list -> will change env var name later
        @admins = []
        @authorizedUsers = []
        if process.env.HUBOT_TEAMS_INITIAL_ADMINS?
            robot.logger.info "#{LogPrefix} Restricting by name, setting admins"
            @admins = process.env.HUBOT_TEAMS_INITIAL_ADMINS.split(",")
            @authorizedUsers = @admins.slice()
        robot.brain.set("admins", @admins)
        robot.brain.set("authorizedUsers", @authorizedUsers)

        @connector  = new BotBuilder.ChatConnector {
            appId: @appId
            appPassword: @appPassword
        }

        @connector.onEvent (events, cb) => @onBotEvents events, cb

    using: (name) ->
        MiddlewareClass = Middleware.middlewareFor(name)
        new MiddlewareClass(@robot)

    onBotEvents: (activities, cb) ->
        @robot.logger.info "#{LogPrefix} onBotEvents"
        activities = [activities] unless Array.isArray activities
        @handleActivity activity for activity in activities

    handleActivity: (activity) ->
        @robot.logger.info "#{LogPrefix} Handling activity Channel: #{activity.source}; type: #{activity.type}"
        console.log("The activity parameter:")
        console.log(activity)
        event = @using(activity.source).toReceivable(activity)
        if event?
            console.log("bot is about to receive the event")
            console.log(event)
            @robot.receive event

    send: (context, messages...) ->
        @robot.logger.info "#{LogPrefix} send"
        @reply context, messages...

    reply: (context, messages...) ->
        @robot.logger.info "#{LogPrefix} reply"
        for msg in messages
            activity = context.user.activity
            payload = @using(activity.source).toSendable(context, msg)
            if !Array.isArray(payload)
                payload = [payload]
            console.log("printing payload for reply: --------------------")
            console.log(payload)
            @connector.send payload, (err, _) ->
                if err
                    throw err
 

    run: ->
        @robot.router.post @endpoint, @connector.listen()
        @robot.logger.info "#{LogPrefix} Adapter running."
        Timers.setTimeout (=> @emit "connected"), 1000

module.exports = {
    Middleware,
    MicrosoftTeamsMiddleware
}

module.exports.use = (robot) ->
    new BotFrameworkAdapter robot
