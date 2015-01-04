window.showSettings = ->
	jQuery.ajax
		url: "#{_root}/get-settings"
		success: (data) ->
			window.settings.create data


window.settings =
	###
	###
	create: (content) ->
		showDialog content

		# Last.fm
		sess = store.get 'lastfm'
		$('.lastfm').addClass if sess? then 'lastfm-enabled' else 'lastfm-disabled'
		$('.disable-lastfm').replaceHTML '%user%', sess.name if sess?

		$('#dialog').on 'click', '.enable-lastfm', (e) ->
			e.preventDefault()
			$('.lastfm').attr 'class', 'lastfm lastfm-loading'
			window.scrobble.startSession()

			(->
				sess = store.get 'lastfm'
				return unless sess?
				this.clearInterval()
				$('.lastfm').attr 'class', 'lastfm lastfm-enabled'
				$('.disable-lastfm').replaceHTML '%user%', sess.name if sess?
			).interval 500

		$('#dialog').on 'click', '.disable-lastfm', (e) ->
			e.preventDefault()

			store.del 'lastfm'
			window.settings.close()
			showSettings()

		# ReplayGain
		rp = store.get 'replaygain'
		$("input[name=replaygain][value=#{rp}]").prop 'checked', true

		# Gapless
		$('#gapless').val store.get('gapless')

		# Misc
		$('.clear-localstorage').on 'click', ->
			window.localStorage.clear()
			window.location.reload()


	###
	###
	close: ->
		gapless = parseFloat $('#gapless').val()
		store.set 'gapless', gapless
		window.player._timeToStart = gapless
		store.set 'replaygain', $('input[name=replaygain]:checked').val() or 'album'
		window.player.setVol()
		removeDialog()
