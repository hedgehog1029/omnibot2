express = require "express"

module.exports = (bot) ->
	app = express()
	api = express.Router({ mergeParams: true })

	api.use((req, res, next) ->
		req.guild = bot.Guilds.get req.params.gid

		next()
	)

	# probably add express.static here

	app.use("/api/:gid", api)

	server =
		app: app
		api: api
		express: express
		start: ->
			app.listen 1350

	return server
