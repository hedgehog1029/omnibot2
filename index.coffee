discordie = require "discordie"
log = require "log4js"
fs = require "fs"
Hjson = require "hjson"

loader = require "./lib/loader"
commandeer = require "./lib/commandeer"

conf = Hjson.parse fs.readFileSync(__dirname + "/config/config.hjson", "utf8")
l = log.getLogger "core"
bot = new discordie autoReconnect: true
webserver = require("./lib/web") bot, conf

eObj =
	cmd: commandeer.manager
	bot: bot
	config: conf
	web: webserver.api
	loader: loader

webserver.app.get "/discord/join/:gid", (req, res) ->
	res.redirect("https://discordapp.com/oauth2/authorize?&client_id=174913532444278784&scope=bot&guild_id=" + req.params.gid)

webserver.app.get "/discord/join", (req, res) ->
	res.redirect("https://discordapp.com/oauth2/authorize?&client_id=174913532444278784&scope=bot")

webserver.api.get "/info", (req, res) ->
	res.send(req.guild)

loader.load eObj
webserver.start()

bot.Dispatcher.on discordie.Events.GATEWAY_READY, (e) ->
	l.info("OmniBot started. Username: #{bot.User.username}")

bot.Dispatcher.on discordie.Events.MESSAGE_CREATE, (e) ->
	commandeer.dispatch e, bot

bot.connect conf.cred
