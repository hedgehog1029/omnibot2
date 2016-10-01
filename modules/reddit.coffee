request = require "request"
reddit = request.defaults {
	baseUrl: "https://api.reddit.com"
	headers:
		"User-Agent": "node:omnibot-reddit:1.0"
}

module.exports =
	name: "reddit"
	init: (a) ->
		a.cmd.command "reddit"
			.alias "r"
			.help "Grab a random image from <subreddit>."
			.usage "<subreddit>"
			.on (e) ->
				if e.has 0
					e.build().reply "Grabbing a random image from **/r/#{e.args[0]}**..."

					reddit.get "/r/#{e.args[0]}/random", { qs: { raw_json: 1 } }, (err, st, res) ->
						post = res[0].data.children[0].data

						if post.preview
							e.file request(post.preview.images[0].source.url), "#{post.id}.png"
						else
							e.mention().reply "I grabbed a post, but it didn't have an image... Try again."
				else
					e.mention().reply "I need a subreddit to grab from!"
			.bind()
