class Command
	constructor: (parent, alias) ->
		@_ = {}
		@_.aliases = [alias]
		@_.parent = parent
		@_.help = "No help provided."
		@_.usage = ""
		@_.permission = null
		@_.commands = {}
		@_.topics = []
		@_.callback = (e) ->
			e.mention().reply "No callback was provided for this command."

		@_.subExec = (e) ->
			unless e.args[0] then return false

			if @commands[e.args[0]]
				@commands[e.args[0]]._run e._shiftArg()
				true
			else false

	alias: (alias) ->
		if alias
			@_.aliases.push alias
			this
		else @_.aliases[0]

	permission: (perm) ->
		if perm
			@_.permission = perm
			this
		else @_.permission

	help: (help) ->
		if help
			@_.help = help
			this
		else @_.help

	usage: (u) ->
		if u
			@_.usage = u
			this
		else @_.usage

	sub: (alias) ->
		new Command this, alias

	on: (cb) ->
		@_.callback = cb
		this

	bind: ->
		@_.parent._bind this
		@_.parent

	_bind: (sub) ->
		@_.topics.push(sub)
		sub._.aliases.forEach (a) =>
			@_.commands[a] = sub

	_run: (e) ->
		unless @_.subExec e
			@_.callback e

class CommandManager
	constructor: ->
		@_ = {}
		@_.commands = {}
		@_.topics = []

	_bind: (cmd) ->
		@_.topics.push(cmd)
		cmd._.aliases.forEach (a) =>
			@_.commands[a] = cmd

	command: (alias) ->
		new Command this, alias

	dispatch: (cmd, e) ->
		unless @_.commands[cmd] then return false

		try
			@_.commands[cmd]._run e
		catch err
			e.mention().reply "There was an error executing your command!\n#{err}"

class MessageBuilder
	constructor: (@msg) ->
		@prefix = ""

	mention: (user) ->
		@prefix = user.mention
		this

	reply: (str) ->
		@msg.channel.sendMessage "#{@prefix} #{str}".trim()

class CommandEvent
	constructor: (@msg, @bot, @args) ->

	build: ->
		new MessageBuilder @msg

	mention: ->
		@build().mention @msg.author

	pm: (msg) ->
		@msg.author.openDM().then (dm) =>
			dm.sendMessage msg

	file: (file, name) ->
		@msg.channel.uploadFile(file, name)

	findVoice: (pos) ->
		name = if pos then @args[pos].toUpperCase() else @args.join(" ").toUpperCase()

		if name is "$VC"
			@msg.member.getVoiceChannel()
		else
			@msg.guild.voiceChannels.find (vc) -> vc.name.toUpperCase() is name

	findText: (pos) ->
		name = @args[pos].toUpperCase()

		@msg.guild.textChannels.find (c) -> c.name.toUpperCase() is name

	validate: (pos, reg) ->
		new RegExp(reg).test(@args[pos])

	has: (pos) ->
		-1 < pos < @args.length

	_shiftArg: ->
		@args.shift()
		this

m =
	manager: new CommandManager
	dispatch: (ev, bot) ->
		msg = ev.message

		if msg.author.id is bot.User.id
			return

		if msg.isPrivate
			return # for now...

		extract = msg.content.split " "
		if extract[0].toLowerCase() is "omni"
			m.manager.dispatch extract[1], new CommandEvent(msg, bot, extract.slice(2))

module.exports = m
