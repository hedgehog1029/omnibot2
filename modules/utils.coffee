request = require "request"

module.exports =
	name: "util"
	init: (a) ->
		a.cmd.command "ping"
			.help "Ping me!"
			.on (e) ->
				ms = Date.now() - e.msg.createdAt.getTime()

				e.mention().reply "Pong! Response time: **#{ms}ms**"
			.bind()
		.command "pong"
			.help "I know."
			.on (e) ->
				e.mention().reply "likes cute asian boys"
			.bind()
		.command "invite"
			.help "Get my invite link."
			.on (e) ->
				e.mention().reply "Click here: http://omni.offbeatwit.ch/discord/join"
			.bind()
		.command "test"
			.help "Test twitch username"
			.on (e) ->
				if e.args[0]
					request.head "https://passport.twitch.tv/usernames/#{e.args[0]}", (err, res, body) ->
						if err
							e.mention().reply "Error requesting twitch.tv servers"
						if res.statusCode is 200
							e.mention().reply "#{e.args[0]} is unavailable. :x:"
						else if res.statusCode is 204
							e.mention().reply "#{e.args[0]} is available! :white_check_mark:"
						else
							e.mention().reply "Unknown status code!"
				else
					e.mention().reply "Specify a name!"
			.bind()