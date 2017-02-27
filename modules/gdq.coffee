request = require "request"
moment = require "moment"

gdq = request.defaults
	baseUrl: "https://gamesdonequick.com/tracker/api/v1/"
	headers: "Content-Type": "application/json"
	json: true

class GDQScheduledRun
	constructor: (raw, @id) ->
		@_json = raw
		@name = raw.name
		@start_time = new Date raw.starttime
		@end_time = new Date raw.endtime
		@cat = raw.category
		@coop = raw.coop
		@runners = raw.runners
		@runners.text = raw.deprecated_runners
		@event = raw.event
		@run_time = raw.run_time
		@console = raw.console
		@order = raw.order
		@game =
			release_year: raw.release_year
			name: raw.display_name
	getRunnerData: ->
		runners = @runners
		Promise.all(for id in runners
			new Promise (resolve, reject) ->
				gdq.get { url: "search", qs: type: "runner", id: id }, (err, res, body) ->
					if err
						reject(err)
					else
						resolve(body[0])
		)

class GDQSchedule
	constructor: (@raw) ->
		@runs = for { fields, pk } in @raw
			new GDQScheduledRun fields, pk
	getUpcoming: ->
		@runs.filter (run) ->
			run.start_time.getTime() >= Date.now()
		.slice 0, 3
	getNext: ->
		@runs.find (run) ->
			run.start_time.getTime() >= Date.now()

schedule = null
module.exports =
	name: "gdq"
	init: (a) ->
		gdq.get { url: "search", qs: type: "run", event: 19 }, (err, res, body) ->
			schedule = new GDQSchedule body

		a.cmd.command "gdq"
			.help "General GamesDoneQuick services and notifications."
			.sub "upcoming"
				.help "View the upcoming runs"
				.on (e) ->
					unless schedule
						e.mention().reply "No GDQ data yet. Either the bot has just started or something went wrong. If the problem persists, contact @offbeatwitch."

					runsTxt = schedule.getUpcoming().map (run) ->
						"**#{run.name}** by #{run.runners.text} #{moment().to(run.start_time)}"

					e.build().reply "Upcoming runs:\n#{runsTxt.join "\n"}"
				.bind()
			.sub "schedule"
				.help "Sends a link to the full schedule."
				.on (e) ->
					e.mention().reply "http://gamesdonequick.com/schedule"
				.bind()
			.sub "stream"
				.help "Sends a link to the current GDQ stream."
				.on (e) ->
					e.mention().reply "http://twitch.tv/gamesdonequick"
				.bind()
			.sub "next"
				.help "Detailed info about the next run"
				.on (e) ->
					unless schedule
						e.mention().reply "No GDQ data yet. Either the bot has just started or something went wrong. If the problem persists, contact @offbeatwitch."

					next = schedule.getNext()

					e.msg.channel.sendTyping()
					next.getRunnerData().then (runners) ->
						rt = runners.map((runner) -> runner.fields.name).join ", "
						embed =
							title: "#{next.name} #{next.cat}"
							type: "rich"
							description: "Starting #{moment(next.start_time).fromNow()}"
							url: "https://gamesdonequick.com/tracker/run/#{next.id}"
							timestamp: next.start_time.toISOString()
							color: 0x00aeff
							author:
								name: "GamesDoneQuick"
								url: "https://gamesdonequick.com"
								icon_url: "https://gamesdonequick.com/static/res/img/favicon/favicon-32x32.png"
							fields: [
								{ name: "Run Time", value: next.run_time, inline: true }
								{ name: "Platform", value: (if next.console is "" then "Unknown" else next.console), inline: true }
								{ name: "Release Year", value: "#{if next.release_year then next.release_year else "Unknown"}", inline: true }
								{ name: (if runners.length > 1 then "Runners" else "Runner"), value: rt }
							]

						e.build().embed embed
				.bind()
			.sub "run"
				.help "Get info about a specific run."
				.usage "<run name>"
				.on (e) ->
					if e.has 0
						search = e.args.join " "

						show = (run) ->
							run.getRunnerData().then (runners) ->
								rt = runners.map((r) -> r.fields.name).join ", "
								e.build().embed
									title: "#{run.name} #{run.cat}"
									type: "rich"
									description: "Starting #{moment(run.start_time).fromNow()}"
									url: "https://gamesdonequick.com/tracker/run/#{run.id}"
									timestamp: run.start_time.toISOString()
									color: 0x00aeff
									author:
										name: "GamesDoneQuick"
										url: "https://gamesdonequick.com"
										icon_url: "https://gamesdonequick.com/static/res/img/favicon/favicon-32x32.png"
									fields: [
										{ name: "Run Time", value: run.run_time, inline: true }
										{ name: "Platform", value: (if run.console is "" then "Unknown" else run.console), inline: true }
										{ name: "Release Year", value: "#{if run.release_year then run.release_year else "Unknown"}", inline: true }
										{ name: (if runners.length > 1 then "Runners" else "Runner"), value: rt }
									]

						e.msg.channel.sendTyping()
						gdq.get { url: "search", qs: type: "run", event: 19, name: search }, (err, res, body) ->
							if err
								e.mention().reply "Error grabbing info from GDQ."
							else
								run = body[0]
								if run
									show(new GDQScheduledRun(run.fields, run.pk))
								else
									e.mention().reply "No run found with that name."
					else
						e.mention().reply "You didn't specify a run to search for!"
				.bind()
			.sub "runner"
				.help "Get info about a specific runner."
				.usage "<runner name>"
				.on (e) ->
					if e.has 0
						search = e.args.join " "

						show = (runner) ->
							e.build().embed
								title: runner.name
								type: "rich"
								url: runner.stream || "http://gamesdonequick.com"
								color: 0x00aeff
								author:
									name: "GamesDoneQuick"
									url: "https://gamesdonequick.com"
									icon_url: "https://gamesdonequick.com/static/res/img/favicon/favicon-32x32.png"
								fields: [
									{ name: "Twitter", value: (if runner.twitter is "" then "None" else "@#{runner.twitter}"), inline: true }
									{ name: "YouTube", value: (if runner.youtube is "" then "None" else runner.youtube), inline: true }
									{ name: "Twitch", value: (if runner.stream is "" then "None" else runner.stream), inline: true }
								]

						e.msg.channel.sendTyping()
						gdq.get { url: "search", qs: type: "runner", name: search }, (err, res, body) ->
							if err
								e.mention().reply "Error grabbing info from GDQ."
							else
								runner = body[0]
								if runner
									show runner.fields
								else
									e.mention().reply "No runner found with that name. Full username is required."
					else
						e.mention().reply "You didn't specify a runner to search for!"
				.bind()
			.sub "donations"
				.help "Get donation information."
				.on (e) ->
					e.msg.channel.sendTyping()
					request.get { url: "https://gamesdonequick.com/tracker/index/agdq2017?json", json: true }, (err, res, body) ->
						if err
							e.mention().reply "Error grabbing current donation data."
						else
							e.build().embed
								title: "Awesome Games Done Quick 2017"
								author:
									name: "GamesDoneQuick"
									url: "https://gamesdonequick.com"
									icon_url: "https://gamesdonequick.com/static/res/img/favicon/favicon-32x32.png"
								color: 0x00aeff
								fields: [
									{ name: "Donors", value: "#{body.count.donors}" }
									{ name: "Current Total", value: "$#{body.agg.amount}", inline: true }
									{ name: "Target", value: "$#{body.agg.target}", inline: true }
								]
				.bind()
			.sub "refresh"
				.help "Refresh GDQ schedule data."
				.on (e) ->
					unless e.msg.author.id is "97707213690249216"
						e.mention().reply "restricted to obw, contact @offbeatwitch#8860 for help."
						return

					gdq.get { url: "search", qs: type: "run", event: 19 }, (err, res, body) ->
						if err
							e.mention().reply "Error refreshing GDQ data."
						else
							schedule = new GDQSchedule body

							e.mention().reply "Refreshed GDQ data."
				.bind()
			.sub "remind"
				.help "Set a reminder for a GDQ run."
				.usage "<run name>"
				.on (e) ->
					if e.has 0
						search = e.args.join " "

						setReminder = (run) ->
							

						gdq.get { url: "search", qs: type: "run", event: 19, name: search }, (err, res, body) ->
							if err
								e.mention().reply "Error grabbing info from GDQ."
							else
								run = body[0]
								if run
									setReminder(new GDQScheduledRun(run.fields, run.pk))
								else
									e.mention().reply "No run found with that name."
					else
						e.mention().reply "You didn't specify a run!"
				.bind()
			.bind()
