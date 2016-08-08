module.exports =
	name: "help"
	init: (a) ->
		a.cmd.command "help"
			.alias "h"
			.help "Get helped."
			.usage "[command]"
			.on (e) ->
				if e.has 0
					command = a.cmd._.commands[e.args[0]]
					subs = command._.topics.map (c) ->
						"**`#{c.alias()}`** #{c._.usage}".trim() + ": #{c._.help}"

					e.pm "Help for command **#{command.alias()}**:\nAliases: `#{command._.aliases.join ", "}`\nUsage: **`#{command.alias()}`** #{command._.usage}\n#{command._.help}\n\n**Sub-commands:**\n#{subs.join "\n"}"
				else
					cmds = a.cmd._.topics.map (c) ->
						"**`#{c.alias()}`** #{c._.usage}".trim() + ": #{c._.help}"

					e.build().reply "Check your PMs."
					e.pm "**OmniBot v2.0 Docs**\nAll commands should be prefixed with `omni`.\n\n#{cmds.join "\n"}"
			.bind()
