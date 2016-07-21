vm = require "vm"

module.exports =
	name: "eval"
	init: (a) ->
		a.cmd.command "eval"
			.help "Evaluate a Javascript input."
			.usage "<JS>"
			.on (e) ->
				if e.msg.author.id isnt "97707213690249216"
					return

				try
					result = vm.runInNewContext e.args.join(" "), { e: e }
				catch err
					e.mention().reply "Error executing script:\n```\n#{err}\n```"
					return

				if result
					e.mention().reply "Executed script with output:\n```\n#{result}\n```"
				else
					e.mention().reply "Executed script with no output."
			.bind()