module.exports =
	name: "help"
	init: (a) ->
		a.cmd.command "help"
			.alias "a"
			.on (e) ->
				
