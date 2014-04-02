window.Playlist = class Playlist
	###
	###
	constructor: ->
		store.get('playlist').forEach (r) ->
			$('#playlist tbody').append r

		$('#playlist-wrapper').scrollbar
			wheelSpeed: 150

		@initMouse()
		@initKeyboard()
		@initSort()

		selectBox $('#playlist-wrapper')


	###
	Set a row as active
	###
	setRowActive: (row) ->
		row = $(row).closest 'tr'

		$('#playlist tr').removeClass 'active'
		row.addClass 'active'
		window.info.setTrack row.attr('data-id')

		# TODO: This can (& should) be improved by looking at the actual
		# position of the first row we want to show
		rowheight = $('#playlist tbody tr:first').outerHeight()
		if row.position().top > $('#playlist-wrapper').height() - rowheight
			$('#playlist-wrapper')[0].scrollTop += row.position().top - rowheight * 2
			$('#playlist-wrapper').scrollbar 'update'
		else if row.position().top < rowheight
			$('#playlist-wrapper')[0].scrollTop -= Math.floor($('#playlist-wrapper').height() / rowheight) * rowheight

	###
	Select a row in the playlist
	###
	selectRow: (row, active=true) ->
		return false unless row
		row = $(row).closest 'tr'
		row.addClass 'selected'
		@setRowActive row if active


	###
	Deselect a row ion the playlist
	###
	deSelectRow: (row, active=true) ->
		row = $(row).closest 'tr'
		row.removeClass 'selected'
		@setRowActive row if active


	###
	Select all rows from .active until `stop'
	###
	selectRowsUntil: (stop, active=true) ->
		return false unless stop
		stop = $(stop).closest 'tr'
		row = $('#playlist .active')

		if row.length is 0
			@selectRow stop, active
			return

		dir = if stop.index() > row.index() then 'next' else 'prev'
		while true
			@selectRow row, false
			if row.is stop
				@setRowActive row if active
				break
			row = if dir is 'next' then row.next() else row.prev()


	###
	Clear all selection
	###
	clearSelection: (active=false) ->
		$('#playlist tr').removeClass 'selected'
		$('#playlist .active').removeClass 'active' if active


	###
	Play this table row
	###
	playRow: (r) ->
		window.player.play $(r).attr('data-id'), $(r).attr('data-length')
		@clearSelection true
		@selectRow r


	###
	Mouse binds
	###
	initMouse: ->
		my = this

		$('body').on 'click', (e) ->
			return unless window._activepane?.is '#playlist-wrapper'
			return if $(e.target).closest('tr').length is 1

			my.clearSelection()

		$('#playlist tbody').on 'click', 'tr', (e) ->
			if e.shiftKey
				my.selectRowsUntil this
			else if e.ctrlKey
				my.selectRow this
			else
				my.clearSelection()
				my.selectRow this

		$('#playlist tbody').on 'dblclick', 'tr', (e) ->
			my.clearSelection()
			my.selectRow this
			my.playRow this


	###
	###
	initKeyboard: ->
		my = this

		# Keybinds
		$('body').bind 'keydown', (e) ->
			return unless _activepane?.is '#playlist-wrapper'

			# A
			if e.ctrlKey and e.keyCode is 65
				e.preventDefault()
				$('#playlist tbody tr').addClass 'selected'
			# Del
			else if e.keyCode is 46
				e.preventDefault()
				albums = []
				$('#playlist .selected').remove()
				window.info.clear()
				my.savePlaylist()
				my.cleanCache()

				# Hack to prevent a seemingly empty playlist, this should be fixed better
				# (this is a problem with perfect scrollbar, the update function should
				# do this
				if $('#playlist tr:last').position().top < 15
					$('#playlist-wrapper')[0].scrollTop = 0
					$('#playlist-wrapper').scrollbar 'update'
			# Up arrow
			else if e.keyCode is 38
				e.preventDefault()
				r = $('#playlist .active')
				return my.selectRow $('#playlist tbody tr:last') if r.length is 0
				return if r.prev().length is 0
				if e.shiftKey
					if r.hasClass('selected') and r.prev().hasClass('selected')
						my.deSelectRow r
					my.selectRow r.prev()
				else if e.ctrlKey
					r.removeClass('active').prev().addClass('active')
				else
					my.clearSelection()
					my.selectRow r.prev()
			# Down arrow
			else if e.keyCode is 40
				e.preventDefault()
				r = $('#playlist .active')
				return my.selectRow $('#playlist tbody tr:first') if r.length is 0
				return if r.next().length is 0
				if e.shiftKey
					if r.hasClass('selected') and r.next().hasClass('selected')
						my.deSelectRow r
					my.selectRow r.next()
				else if e.ctrlKey
					r.removeClass('active').next().addClass('active')
				else
					my.clearSelection()
					my.selectRow r.next()
			# Page down
			else if e.keyCode is 34
				e.preventDefault()
				n = Math.floor $('#playlist-wrapper').height() / $('#playlist tr:last').outerHeight()
				if e.shiftKey
					r = my.selectRowsUntil $('#playlist .active').findNext('tr', n)
					my.selectRowsUntil $('#playlist tbody tr:last') if r is false
				else
					my.clearSelection()
					r = my.selectRow $('#playlist .active').findNext('tr', n)
					my.selectRow $('#playlist tbody tr:last') if r is false
			# Page up
			else if e.keyCode is 33
				e.preventDefault()
				n = Math.floor $('#playlist-wrapper').height() / $('#playlist tr:last').outerHeight()
				if e.shiftKey
					r = my.selectRowsUntil $('#playlist .active').findPrev('tr', n)
					my.selectRowsUntil $('#playlist tbody tr:first') if r is false
				else
					my.clearSelection()
					r = my.selectRow $('#playlist .active').findPrev('tr', n)
					my.selectRow $('#playlist tbody tr:first') if r is false
			# Home
			else if e.keyCode is 36
				e.preventDefault()
				if e.shiftKey
					my.selectRowsUntil $('#playlist tbody tr:first')
				else if e.ctrlKey
					$('#playlist .active').removeClass 'active'
					$('#playlist tbody tr:first').addClass 'active'
				else
					my.clearSelection()
					my.selectRow $('#playlist tbody tr:first')
			# End
			else if e.keyCode is 35
				e.preventDefault()
				if e.shiftKey
					my.selectRowsUntil $('#playlist tbody tr:last')
				else if e.ctrlKey
					$('#playlist .active').removeClass 'active'
					$('#playlist tbody tr:last').addClass 'active'
				else
					my.clearSelection()
					my.selectRow $('#playlist tbody tr:last')
			# Enter
			else if e.keyCode is 13
				e.preventDefault()
				$('#playlist .active').dblclick()


	###
	Sorting
	###
	initSort: ->
		my = this

		sort = null
		$('#playlist-thead').on 'click', '.cell', (e) ->
			h = $(this)

			psort = null
			if $('#playlist-thead').find('.icon-sort-up').length > 0
				psort = $('#playlist-thead').find('.icon-sort-up').parent()
			else if $('#playlist-thead').find('.icon-sort-down').length > 0
				psort = $('#playlist-thead').find('.icon-sort-down').parent()

			psort = null if psort and h[0] is psort[0]

			dir = null
			if h.find('.icon-sort-up').length > 0
				dir = 'down'
				h.find('i').attr 'class', 'icon-sort-down'
			else if h.find('.icon-sort-down').length > 0
				dir = 'up'
				h.find('i').attr 'class', 'icon-sort-up'
			else
				dir = 'up'
				h.find('i').attr 'class', 'icon-sort-up'

			psort?.find('i').attr 'class', ''

			body = $('#playlist tbody')
			rows = body.find('tr').toArray()

			n = h.index()
			pn = psort?.index()
			int = (num) -> parseFloat num.replace(':', '.')

			sortFun = (rowa, rowb) ->
				if rowa.tagName?.toLowerCase() is 'tr'
					a = $(rowa).find("td:eq(#{n})").text()
					b = $(rowb).find("td:eq(#{n})").text()
					inpsort = false
				else
					inpsort = true
					a = $(rowa).text()
					b = $(rowb).text()

				if dir is 'up' and h.attr('data-sort') is 'numeric'
					fun = ->
						return 0 if int(a) is int(b)
						return if int(a) > int(b) then 1 else -1
				else if dir is 'down' and h.attr('data-sort') is 'numeric'
					fun = ->
						return 0 if int(a) is int(b)
						return if int(b) > int(a) then 1 else -1
				else if dir is 'up'
					fun = -> a.localeCompare b
				else if dir is 'down'
					fun = -> b.localeCompare a

				r = fun()

				if r is 0 and not inpsort and psort?
					r = sortFun $(rowa).find("td:eq(#{pn})"), $(rowb).find("td:eq(#{pn})")

				return r

			rows.sort sortFun

			body.html ''
			rows.forEach (r) -> body.append r
			my.savePlaylist()


	###
	Save the playlist to localStorage
	###
	savePlaylist: ->
		store.set 'playlist', $$('#playlist tbody tr').map (r) -> r.outerHTML
		$('#playlist-wrapper').scrollbar 'update'
		@headSize()


	###
	Get currently playing track
	###
	getPlaying: -> $('#playlist .playing')


	###
	###
	cleanCache: ->
		tracks = []
		albums = []
		artists = []

		$$('#playlist tbody tr').forEach (row) ->
			trackid = $(row).attr 'data-id'
			albumid = window._cache.tracks[trackid]?.album
			artistid = window._cache.albums[albumid]?.artist

			tracks.push trackid unless trackid in tracks
			albums.push albumid unless albumid in albums
			artists.push artistid unless artistid in artists

		deleted = []
		for k, t of window._cache.tracks
			unless t.id in tracks
				deleted.push t.id
				delete window._cache.tracks[k]

		for k, t of window._cache.albums
			delete window._cache.albums[k] unless t.id in albums

		for k, t of window._cache.artists
			delete window._cache.artists[k] unless t.id in artists


	###
	###
	headSize: ->
		$('#playlist thead th').each (i, cell) ->
			$("#playlist-thead .cell:eq(#{i})").css 'width', "#{$(cell).width() + 2}px"
		w = $('#playlist-thead').width() - ($('#playlist-thead .cell:last').position().left + $('#playlist-thead .cell:last').outerWidth())
		$('#playlist-thead > .cell:last').css 'width', "+=#{w}px"


###
###
selectBox = (target) ->
	target = $(target)

	dragging = false
	maystart = false
	startrow = null
	box = null
	startX = 0
	startY = 0
	prev = ''

	# Start
	target.on 'mousedown.selectbox', (e) ->
		maystart = true
		startX = e.pageX
		startY = e.pageY

	# End
	$('body').on 'mouseup.selectbox', (e) ->
		maystart = false
		dragging = false
		startrow = null
		box?.remove()
		box = null
		prev = ''

	# Move
	$('body').on 'mousemove.selectbox', (e) ->
		if not dragging and maystart and (Math.abs(startX - e.pageX) > 5 or Math.abs(startY - e.pageY) > 5)
			dragging = true

			# HACK!!
			window._activepane = $('#playlist-wrapper')
			$('.pane-active').removeClass 'pane-active'
			window._activepane.addClass 'pane-active'

			$('body').append '<div id="selectbox"></div>'
			box = $('#selectbox')

			box.css
				left: "#{startX}px"
				top: "#{startY}px"

			window.getSelection?().empty?()
			window.getSelection?().removeAllRanges?()
			document.selection?.empty()
			document.body.focus()
			e.preventDefault()

		return unless dragging

		row = $(e.target).closest 'tr'
		if row.length > 0
			startrow = row unless startrow?
			if row.index() > startrow.index()
				from = startrow.index()
				to = row.index() + 1
			else if row.index() < startrow?.index()
				from = row.index()
				to = startrow.index() + 1
			else
				from = row.index()
				to = row.index()

			if "#{from}-#{to}" isnt "#{prev.from}-#{prev.to}"
				if from isnt prev.from
					$("#playlist tr:lt(#{from})").removeClass 'selected'
				if to isnt prev.to
					$("#playlist tr:gt(#{to})").removeClass 'selected'

				window.playlist.selectRow r, false for r in $('#playlist tbody tr').slice from, to
				window.playlist.selectRow row
			prev = from: from, to: to

		w = $(window).width()
		h = $(window).height()

		if e.pageX > startX
			l = startX
			r = w - e.pageX
		else
			l = e.pageX
			r = w - startX

		if e.pageY > startY
			t = startY
			b = h - e.pageY
		else
			t = e.pageY
			b = h - startY

		offs = $('#playlist-wrapper').offset()
		l = Math.max l, offs.left
		#r = Math.max r, $('#playlist').offset().left + $('#playlist').width()
		#t = Math.max t, $('#playlist').offset().top
		#b = Math.max b, offs.top + $('#playlist-wrapper').height()

		box.css
			left: l + 'px'
			right: r + 'px'
			top: t + 'px'
			bottom: b + 'px'
