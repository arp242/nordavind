window.showSettings = ->
	jQuery.ajax
		url: "#{_root}/get-settings"
		success: (data) ->
			window.settings.create data


window.settings =
	###
	###
	create: (content) ->
		$('body').append """
			<div id="backdrop"></div>
			<div id='dialog'>
				<div class="content">#{content}</div>
				<div class="buttons"><button class="btn close">Close</div></div>
			</div>
		"""

		$(window).on 'keydown.dialog', (e) ->
			return unless e.keyCode is 27
			$(window).off 'keydown.dialog'
			window.settings.close()

		$('#dialog').animate {
			top: '100px'
			opacity: '1'
		}, {
			duration: 200
		}

		$('#backdrop').animate {
			opacity: '0.5'
		}, {
			duration: 200
		}

		# Last.fm
		sess = store.get 'lastfm'
		$('.lastfm').addClass if sess? then 'lastfm-enabled' else 'lastfm-disabled'
		$('.disable-lastfm').replaceHTML '%user%', sess.name if sess?

		$('#dialog .close').on 'click', (e) ->
			e.preventDefault()
			window.settings.close()

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
			window.settings.create()

		# ReplayGain
		rp = store.get 'replaygain'
		$("input[name=replaygain][value=#{rp}]").prop 'checked', true


	###
	###
	close: ->
		store.set 'replaygain', $('input[name=replaygain]:checked').val()
		window.player.setVol()
		$('#dialog').remove()
		$('#backdrop').remove()
