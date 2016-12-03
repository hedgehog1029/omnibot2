express = require "express"
jwt = require "jsonwebtoken"
request = require "request"

client_id = "174913532444278784"

module.exports = (bot, conf) ->
	app = express()
	secret = conf.web.secret
	api = express.Router({ mergeParams: true })

	app.use(express.static(__dirname + "/public"))
	api.use((req, res, next) ->
		req.guild = bot.Guilds.get req.params.gid

		if req.get("Authorization")
			try
				req.user = jwt.verify(req.get("Authorization"), secret)
			catch err
				res.status(401).send({ status: "bad", msg: "401 Unauthorized: Invalid token" })

		next()
	)

	# it's time to oauth
	app.get "/discord/login", (req, res) ->
		res.redirect "https://discordapp.com/oauth2/authorize?client_id=#{client_id}&scope=identify+guilds&response_type=code"

	app.get "/discord/hippopotamus", (req, res) ->
		code = req.query.code

		request.post {
			url: "https://discordapp.com/api/oauth2/token"
			form: {
				grant_type: "authorization_code"
				code: code
				client_id: client_id
				redirect_uri: "http://omni.offbeatwit.ch/discord/hippopotamus"
			}
			json: true
		}, (err, response, body) ->
			jtoken = jwt.sign {
				discord_tokens: {
					access: body.access_token
					refresh: body.refresh_token
					type: body.token_type
				}
			}, secret

			res.redirect "http://omni.offbeatwit.ch/\#/dash?token=#{jtoken}"

	app.use "/pr", (req, res, next) ->
		if req.get("Authorization")
			try
				req.user = jwt.verify(req.get("Authorization"), secret)

				next()
			catch err
				res.status(401).send({ status: "bad", msg: "401 Unauthorized: Invalid token" })

		unless req.user
			res.status(401).send({ status: "bad", msg: "401 Unauthorized: No token provided" });
			return

	app.get "/pr/guilds", (req, res) ->
		request.get {
			url: "https://discordapp.com/api/users/@me/guilds"
			headers:
				"Authorization": "Bearer #{req.user.discord_tokens.access}"
			json: true
		}, (err, response, body) ->
			if err or response.statusCode isnt 200
				res.send { status: "bad", msg: "unknown error" }
				return

			guildList = body.filter (guild) ->
				bot.Guilds.get(guild.id) != null

			res.send guildList

	app.get "/pr/user", (req, res) ->
		request.get {
			url: "https://discordapp.com/api/users/@me"
			headers:
				"Authorization": "Bearer #{req.user.discord_tokens.access}"
			json: true
		}, (err, response, body) ->
			if err
				res.send { status: "bad", msg: "unknown error" }
				return

			res.send body

	app.use("/api/:gid", api)

	server =
		app: app
		api: api
		express: express
		start: ->
			app.listen 1350

	return server
