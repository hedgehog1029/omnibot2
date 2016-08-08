ytdl = require "ytdl-core"
ffmpeg = require "fluent-ffmpeg"
YouTube = require "youtube-node"
lame = require "lame"
request = require "request"
consumer = require "../lib/util/playlist-consumer"

utils = require "util"

# WINDOWS ONLY
#ffmpeg.setFfmpegPath "#{__dirname}/../ffmpeg/ffmpeg.exe"

Jukebox =
	channels: {}
	_queue: {}
	connections: {}
	volume: {}
	nowplaying: {}

class Track
	constructor: (@title, @type, @url) ->

	resolveStream: (writable, conn) ->
		if @type is "youtube"
			ffmpeg().input(ytdl(@url)).noVideo().format("mp3").on("error", (err) ->
				console.log(err);

				if err then Jukebox.playNext(conn);
			).pipe writable, { end: true }
		else
			request(@url).pipe writable
	play: (conn) ->
		@decoder = new lame.Decoder()

		@decoder.on "format", (fmt) =>
			vccs = conn.getEncoderStream { sampleRate: fmt.sampleRate, channels: fmt.channels, frameDuration: 60 }
			vccs.resetTimestamp()

			vccs._encoder.setVolume if Jukebox.volume[conn.guildId] then Jukebox.volume[conn.guildId] else 10

			@decoder.pipe vccs

			@decoder.once "end", ->
				Jukebox.playNext(conn)

			Jukebox.nowplaying[conn.guildId] = this

		@resolveStream @decoder, conn

Jukebox.queue = (e, guild, title, type, url) ->
	unless Jukebox._queue[guild.id]
		Jukebox._queue[guild.id] = []

	Jukebox._queue[guild.id].push(new Track title, type, url)

	Jukebox.queueUpdate e, guild

Jukebox.ytQueue = (url, e) ->
	ytdl.getInfo url, (err, info) ->
		if err then return

		Jukebox.queue e, e.msg.guild, info.title, "youtube", url

		e.mention().reply "Queued **#{info.title}** from YouTube."

Jukebox.join = (e, guild, cb) ->
	unless Jukebox.channels[guild.id]
		e.mention().reply "No channel set to join in this guild!"
		return

	if Jukebox.connections[guild.id]
		cb Jukebox.connections[guild.id]
		return

	Jukebox.channels[guild.id].join().then (vci) ->
		Jukebox.connections[guild.id] = vci.voiceConnection

		cb vci.voiceConnection

Jukebox.playNext = (conn) ->
	unless Jukebox._queue[conn.guildId]
		return

	next = Jukebox._queue[conn.guildId].shift()

	console.log("Playing next");

	if next
		next.play conn
	else
		conn.channel.leave();
		conn.disconnect();

		delete Jukebox.connections[conn.guildId];

Jukebox.queueUpdate = (e, guild) ->
	unless Jukebox._queue[guild.id]
		Jukebox._queue[guild.id] = []

	unless Jukebox.connections[guild.id]
		Jukebox.join e, guild, (vcc) ->
			Jukebox.playNext vcc

Jukebox.volUpdate = (guild, vol) ->
	if Jukebox.connections[guild.id]
		Jukebox.connections[guild.id].getEncoderStream()._encoder.setVolume vol

module.exports =
	name: "jukebox"
	init: (a) ->
		yt = new YouTube()

		yt.setKey a.config.yt.key
		consumer.setApiKey a.config.yt.key

		a.web.get "/jukebox/np", (req, res) ->
			playing = Jukebox.nowplaying[req.guild.id]

			if playing
				res.send({
					title: playing.title
					type: playing.type
					url: playing.url
				})
			else
				res.send({})

		a.web.get "/jukebox/queue", (req, res) ->
			if Jukebox._queue[req.guild.id]
				res.send({
					queue: Jukebox._queue[req.guild.id].map (playing) ->
						{
							title: playing.title
							type: playing.type
							url: playing.url
						}
				})
			else
				res.send({ queue: [] })

		a.cmd.command "jukebox"
			.alias "play"
			.help "Play some sweet tunes!"
			.sub "join"
				.help "Join a voice channel."
				.usage "<voice channel>"
				.on (e) ->
					vc = e.findVoice 0
					Jukebox.channels[e.msg.guild.id] = vc

					e.mention().reply "Set **#{vc.name}** as the music channel for this guild. I'll join when there is music to play!"
				.bind()
			.sub "yt"
				.alias "youtube"
				.help "Queue a song from YouTube."
				.usage "<url/search>"
				.on (e) ->
					if e.validate 0, /http(?:s*):\/\/(?:www\.)*youtube\.com\/watch\?v=(\w*)/i
						Jukebox.ytQueue e.args[0], e
					else if e.validate 0, /http(?:s*):\/\/(?:www\.)*youtube\.com\/playlist\?list=(\w*)/
						matches = e.args[0].match(/http(?:s*):\/\/(?:www\.)*youtube\.com\/playlist\?list=(\w*)/)

						console.log(matches[1]);

						if matches[1] isnt null
							consumer.consume matches[1], (videos) ->
								e.mention().reply "Queued that playlist from YouTube. Use `omni jukebox queue` to check the queue."
								console.log(videos);

								unless Jukebox._queue[e.msg.guild.id]
									Jukebox._queue[e.msg.guild.id] = []

								videos.forEach (video) ->
									Jukebox._queue[e.msg.guild.id].push(new Track video.title, "youtube", video.url)

								Jukebox.queueUpdate e, e.msg.guild
					else
						yt.search e.args[0], 1, (err, result) ->
							if err then return

							if result.items.length > 0
								Jukebox.ytQueue "http://www.youtube.com/watch?v=#{result.items[0].id.videoId}", e
							else
								e.mention().reply "No videos found!"
				.bind()
			.sub "soundcloud"
				.alias "sc"
				.help "Queue a song from SoundCloud"
				.usage "<search>"
				.on (e) ->
					e.mention().reply "NYI"
				.bind()
			.sub "url"
				.help "Queue a song from a URL"
				.usage "<url>"
				.on (e) ->
					name = e.args[0].substring e.args[0].lastIndexOf("/") + 1

					Jukebox.queue e, e.msg.guild, name, "url", e.args[0]

					e.mention().reply "Queued **#{name}** to be played."
				.bind()
			.sub "queue"
				.alias "q"
				.help "View the current guild queue."
				.on (e) ->
					unless Jukebox._queue[e.msg.guild.id]
						e.mention().reply "There's no queue in this guild!"
						return

					q = Jukebox._queue[e.msg.guild.id].map (track, i) ->
						"**#{i + 1}. #{track.title}**"

					unless q.length is 0
						e.mention().reply "Current queue:\n#{q.join "\n"}"
					else
						e.mention().reply "The queue is currently empty."
				.bind()
			.sub "skip"
				.help "Skip the currently-playing song."
				.on (e) ->
					unless Jukebox.nowplaying[e.msg.guild.id]
						e.mention().reply "No song currently playing!"
						return
					playing = Jukebox.nowplaying[e.msg.guild.id]

					unless Jukebox.connections[e.msg.guild.id]
						e.mention().reply "No active connection!"
						return

					try
						playing.decoder.unpipe()
						Jukebox.playNext Jukebox.connections[e.msg.guild.id]

						e.mention().reply "Skipped song **#{playing.title}**."
					catch err
						e.mention().reply "There was an error skipping the song. Perhaps it already finished."
				.bind()
			.sub "nowplaying"
				.alias "np"
				.help "Get the currently-playing song."
				.on (e) ->
					if Jukebox.nowplaying[e.msg.guild.id]
						playing = Jukebox.nowplaying[e.msg.guild.id]

						e.mention().reply "Now playing: **#{playing.title}**"
					else
						e.mention().reply "No song currently playing!"
				.bind()
			.sub "leave"
				.help "Disconnect from the voice channel."
				.on (e) ->
					Jukebox.channels[e.msg.guild.id].leave()
					Jukebox.connections[e.msg.guild.id].disconnect()
					delete Jukebox.connections[e.msg.guild.id]

					e.mention().reply "Left the voice channel."
				.bind()
			.sub "volume"
				.help "Set the volume of Omni. Warning: 100 is _loud_. Recommended: 10"
				.usage "<volume>"
				.on (e) ->
					if e.validate 0, /\d+/
						vol = parseInt(e.args[0])

						if 0 < vol < 101
							Jukebox.volume[e.msg.guild.id] = vol;
							Jukebox.volUpdate e.msg.guild, vol

							e.mention().reply "Updated the volume to **#{vol}**"
						else
							e.mention().reply "The volume must be between 0 and 100"
					else
						e.mention().reply "You need to specify a number!"
				.bind()
			.bind()
