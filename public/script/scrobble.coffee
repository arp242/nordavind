class Scrobble
	###
	The secret key is supposed to be, well, secret ... Which is somewhat
	impossible in an open-source application.

	Please don't misuse this key :-)

	Also, if you make modifications to Nordavind, then please register your own
	key. Many thanks :-)
	###
	secret: '0ce163b13c9d0ae05fd152a9a5b92a45'
	key: '2741bbf6e0178180846e814f042cfbcd'
	root: 'http://ws.audioscrobbler.com/2.0'

	enabled: false

	constructor: ->
		@enabled = true if window.localStorage.getItem 'nordavind_lastfm'


	###
	###
	startSession: ->
		my = this

		window.open "http://www.last.fm/api/auth/?api_key=#{@key}" +
			"&cb=#{window.location.href.replace(/\/$/, '')}/lastfm-callback"

		(->
			token = localStorage.getItem 'nordavind_token'
			return if token is null
			localStorage.removeItem 'nordavind_token'
			this.clearInterval()

			my._req
				method: 'auth.getSession'
				token: token
			, (data) ->
				window.store.set 'lastfm', data.session
				my.enabled = true
		).interval 500


	###
	###
	nowPlaying: (info) ->
		return unless @enabled

		info['method'] = 'track.updateNowPlaying'
		@_req info, null, 'post'


	###
	A track should only be scrobbled when the following conditions have been
	met:
	- The track must be longer than 30 seconds.
	- And the track has been played for at least half its duration, or for 4
	  minutes (whichever occurs earlier.)
	###
	scrobble: (info) ->
		return unless @enabled

		info['method'] = 'track.scrobble'
		@_req info, null, 'post'


	###
	Make a request to the API
	###
	_req: (paramsobj, cb=null, type='get') ->
		paramsobj['api_key'] = @key
		paramsobj['format'] = 'json'

		session = window.store.get 'lastfm'
		paramsobj['sk'] = session.key if session?

		params = ([k, v] for own k, v of paramsobj)
		params.sort (a, b) -> a[0].localeCompare b[0]
		sig = md5 ("#{k}#{v}" for [k, v] in params when k not in ['format', 'callback']).join('') + @secret
		urlparams = ("#{encodeURIComponent k}=#{encodeURIComponent v}" for [k, v] in params).join '&'

		#session = window.store.get 'lastfm'
		#urlparams += "&sk=#{session.key}" if session?

		jQuery.ajax
			url: "#{@root}?#{urlparams}&api_sig=#{sig}"
			type: 'post'
			dataType: 'json'
			success: (data) ->
				if data.error
					alert "LastFM error #{data.error}: #{data.message}"
					return
				cb.call null, data if cb


window.scrobble = new Scrobble
