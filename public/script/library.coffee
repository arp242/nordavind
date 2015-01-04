window.Library = class Library
	###
	###
	constructor: ->
		$('#library ol').scrollbar
			wheelSpeed: 150

		@selectRow $('#library li:first')
		@initFilter()
		@initEditFilter()
		@initMouse()
		@initKeyboard()
		@initRandom()

	
	###
	###
	updateScrollbar: -> $('#library ol').scrollbar 'update'


	###
	Toggle artist open/close
	###
	toggleArtist: (row) ->
		row = row.closest 'li'
		return unless row.is '.artist'

		if row.find('i').attr('class') is 'icon-expand-alt'
			row.find('i').attr 'class', 'icon-collapse-alt'
			hide = false
		else
			row.find('i').attr 'class', 'icon-expand-alt'
			hide = true

		n = row.next()
		while true
			break unless n.hasClass 'album'

			if hide
				n.css 'display', 'none'
			else
				if $('#search input').val() is '' or n.attr('data-match') is 'true'
					n.css 'display', 'block'
			n = n.next()

		@updateScrollbar


	###
	Add album to playlist
	###
	addAlbumToPlaylist: (albumId) ->
		jQuery.ajax
			url: "#{_root}/get-album/#{albumId}"
			type: 'get'
			dataType: 'json'
			#error: (req, st) -> alert req.responseText if st isnt 'abort'
			success: (data) ->
				pl = $('#playlist tbody')
				save = []

				window._cache['artists'][data.artist.id] = data.artist
				window._cache['albums'][data.album.id] = data.album
				for t in data.tracks
					# Allow a track to be in the playlist only once; since
					# everything is done by track-id
					continue if $("#playlist tr[data-id=#{t.id}]").length > 0

					window._cache['tracks'][t.id] = t
					row = """<tr data-id="#{t.id}" data-length="#{t.length}">
						<td></td>
						<td>#{t.discno}.#{if t.trackno < 10 then 0 else ''}#{t.trackno}</td>
						<td>#{data.artist.name.quote()} - #{data.album.name.quote()}</td>
						<td>#{t.name.quote()}</td>
						<td>#{displaytime t.length}</td>
					</tr>"""

					pl.append row
					save.push row
				$('#playlist-wrapper').scrollbar 'update'
				window.playlist.headSize()
				store.set 'playlist', store.get('playlist').concat save


	###
	Select artist/album
	###
	selectRow: (row) ->
		row = row.closest 'li'
		return false unless row

		$('#library .active').removeClass 'active'
		row.addClass 'active'

		if row.position().top > $('#library ol').height() or row.position().top < 0
			$('#library ol')[0].scrollTop += row.closest('li').position().top
			@updateScrollbar


	###
	Add album to playlist
	###
	addAlbum: (row) -> @addAlbumToPlaylist row.closest('li').attr 'data-id'


	###
	Filter
	###
	initFilter: ->
		my = this

		t = null
		pterm = null
		
		$('#search select').on 'change', (e) ->
			v = $(this).val()
			$('#search input')
				.attr 'data-id', $(this).find(':selected').attr('data-id')
				.val v
				.change()
			pterm = null
			t = null
			clearTimeout t if t
			$(this).val 0

		dofilter = (target) ->
			term = target.val().trim()
			return if term is pterm  # Unchanged

			target.removeClass 'invalid'
			target.parent().find('.error').remove()

			pterm = term
			if term is ''
				$('#library .artist').show()
				$('#library .album').hide()
				return

			if term[0] == '$'
				my.sql_search term
				return

			try
				term = new RegExp term
			catch exc
				target.addClass 'invalid'
				target.after '<span class="error">Invalid regular expression</span>'
				return

			$('#library li').hide()
			$('#library ol')[0].scrollTop = 0
			$$('#library li').forEach (row) ->
				row = $(row)
				if row.text().toLowerCase().match(term) or row.attr('data-name_tr')?.toLowerCase().match(term)
					if row.is('.artist')
						row.show()
						n = row.next()
						while true
							break unless n.hasClass 'album'
							n.attr 'data-match', 'true'
							n = n.next()
					else
						row.attr 'data-match', 'true'
						row.findPrev('.artist').show()
			@updateScrollbar

		filter = (e) ->
			clearTimeout t if t
			t = dofilter.timeout 400, [$(e.target)]

		$('#search input').on 'keydown', filter
		$('#search input').on 'change', filter


	###
	###
	sql_search: (term) ->
		my = this

		do_filter = (data) ->
			unless data.success
				alert data.error
				return

			$('#library li').hide()
			$('#library ol')[0].scrollTop = 0
			data.albums.forEach (id) ->
				row = $("#library .album[data-id=#{id}]")
				row.findPrev('.artist').show()
				row.attr 'data-match', 'true'
			my.updateScrollbar

		if term[term.length - 1] is '$'
			jQuery.ajax
				url: '/sql_search'
				type: 'get'
				dataType: 'json'
				data:
					sql: term
				success: do_filter


	###
	Bind mouse events
	###
	initMouse: ->
		my = this

		$('#library ol').on 'click', 'li span', -> my.selectRow $(this)
		$('#library ol').on 'click', '.artist i', -> my.toggleArtist $(this)
		$('#library ol').on 'dblclick', '.artist span', (e) ->
			e.preventDefault()
			my.selectRow $(this)
			my.toggleArtist $(this)

		$('#library ol').on 'dblclick', '.album span', (e) ->
			e.preventDefault()
			my.selectRow $(this)
			my.addAlbum $(this)

		# Middle mouse button
		$('#library ol').on 'mousedown', '.artist span', (e) ->
			return unless e.button is 1

			e.preventDefault()
			my.selectRow $(this)

			next = $(this).closest('li').next()
			while true
				break unless next.is('.album')
				my.addAlbum next
				next = next.next()

		$('#library ol').on 'mousedown', '.album span', (e) ->
			return unless e.button is 1

			e.preventDefault()
			my.selectRow $(this)
			my.addAlbum $(this)


	###
	Keybinds
	###
	initKeyboard: ->
		my = this
		chain = ''
		timer = null
		cleartimer = null
		$('body').on 'keydown', (e) ->
			return unless window._activepane?.is '#library'
			return if document.activeElement?.tagName?.toLowerCase() is 'input'
			return if e.ctrlKey or e.altKey

			events =
				27: -> # Esc
					clearTimeout timer if timer
					clearTimeout cleartimer if cleartimer
				38: -> my.selectRow $('#library .active').findPrev 'li:visible' # Up
				40: -> my.selectRow $('#library .active').findNext 'li:visible' # Down
				39: -> # Right
					act = $('#library .active')
					if act.is '.artist'
						if act.next().is(':visible')
							my.selectRow act.next()
						else
							my.toggleArtist act
				37: -> # Left
					act = $('#library .active')
					if act.is('.album')
						my.selectRow act.findPrev('.artist')
					else if act.is('.artist') and act.next().is(':visible')
						my.toggleArtist act
				33: -> # Page up
					n = Math.floor $('#library ol').height() / $('#library li:first').outerHeight()
					r = my.selectRow $('#library .active').findPrev('li:visible', n)
					my.selectRow $('#library li:first') if r is false
				34: -> # Page down
					n = Math.floor $('#library ol').height() / $('#library li:first').outerHeight()
					r = my.selectRow $('#library .active').findNext('li:visible', n)
					my.selectRow $('#library li:last') if r is false
				36: -> my.selectRow $('#library li:first') # Home
				35: -> my.selectRow $('#library li:last').findPrev('.artist') # End
				13: -> # Enter
					act = $('#library .active')
					my.toggleArtist act if act.is('.artist')
					my.addAlbum act if act.is('.album')

			if events[e.keyCode]?
				e.preventDefault()
				chain = ''
				events[e.keyCode]()
			# 0-9a-z & space
			else if e.keyCode is 32 or (e.keyCode > 46 and e.keyCode < 91)
				e.preventDefault()
				chain += String.fromCharCode(e.keyCode).toLowerCase()
				clearTimeout timer if timer
				f = (chain) ->
					$('#library li').each (i, elem) ->
						elem = $(elem)
						if elem.is(':visible') and
							(elem.text().toLowerCase().indexOf(chain) is 0 or
							elem.attr('data-name_tr')?.toLowerCase().indexOf(chain) is 0)
								my.selectRow elem
								return false

				timer = f.timeout 100, [chain]

				clearTimeout cleartimer if cleartimer
				cleartimer = (-> chain = '').timeout 1500

	###
	###
	initRandom: ->
		$(document).on 'click', '.random-album', (e) ->
			e.preventDefault()

			# TODO: If an album is already in the playlist, this is ignored, we
			# should detect this, and try again (to ensure an album is always
			# added)
			if $('#search input').val() isnt ''
				list = $('#library .album[data-match]')
			else
				list = $('#library .album')

			rnd = list.eq Math.floor(Math.random() * list.length)
			rnd.find('span').dblclick()

	###
	###
	initEditFilter: ->
		$(document).on 'click', '.save-search', (e) ->
			id = $('#search input').attr 'data-id'
			name = $("#saved-searches option[data-id=#{id}]").val()

			html = """
				<label for="save-search-name">Name</label>
				<input id="save-search-name" type="text" value="#{name.quote()}">
			"""

			if id
				html += """<br>
					<label>
						<input type="checkbox" checked>
						Edit existing search (instead of creating a new)
					</label>
				"""


			showDialog html

			#def save_search(search, name=None, search_id=0):
			#sel = $('#saved-searches').val()
			#url = "/#{$('#search input').val()}"
			#name = prompt('Enter a name for this search', $('#saved-searched :selected'))

			return

			if sel
				url = ""
			else
				url = ""

			jQuery.ajax
				url: url
				type: 'post'
				dataType: 'json'
				success: ->
