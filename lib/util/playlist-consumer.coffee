request = require "request"

BASE_URL = "https://www.googleapis.com/youtube/v3/playlistItems"
API_KEY = ""

# PLsUzIJHtHaxXryQ2v8uTXMMs6M5x3YvUC

# specify empty string as page token for first request
consumeOne = (id, pageToken, cb) ->
	request(BASE_URL, {
		qs: {
			part: "snippet"
			key: API_KEY
			maxResults: 50
			playlistId: id
			pageToken: pageToken
		}
		json: true
	}, (err, res, body) ->
		if not err and res.statusCode is 200
			cb body
	)

consumeList = (id, callb) ->
	result = []

	cb = (res) ->
		result = result.concat(res.items)

		if res.nextPageToken
			consumeOne id, res.nextPageToken, cb
		else
			callb result

	consumeOne id, "", cb

module.exports.consume = (id, cb) ->
	consumeList id, (items) ->
		cb items.map (item) ->
			{
				title: item.snippet.title
				url: "http://www.youtube.com/watch?v=#{item.snippet.resourceId.videoId}"
			}

module.exports.setApiKey = (key) ->
	API_KEY = key
