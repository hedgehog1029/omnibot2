discordie = require "discordie"
log = require "log4js"
fs = require "fs"
Hjson = require "hjson"

loader = require "./lib/loader"
commandeer = require "./lib/commandeer"

conf = Hjson.parse fs.readFileSync(__dirname + "/config/config.hjson", "utf8")
l = log.getLogger "core"
bot = new discordie

eObj =
	cmd: commandeer.manager
	bot: bot
	config: conf

loader.load eObj

bot.Dispatcher.on discordie.Events.GATEWAY_READY, (e) ->
	l.info("OmniBot started. Username: #{bot.User.username}")

bot.Dispatcher.on discordie.Events.MESSAGE_CREATE, (e) ->
	commandeer.dispatch e, bot

bot.connect conf.cred