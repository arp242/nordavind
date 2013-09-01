#
# http://code.arp242.net/nordavind
#
# Copyright © 2013 Martin Tournoij <martin@arp242.net>
# See below for full copyright
#


# Script root
_root = ''

# Easy reference to our <audio> element
_audio = $('audio')[0]

# jQuery request to fetch info
_inforeq = null

# Current active pane
_activepane = null

# Current playing track
_curplaying =
	trackId: null
	length: 1

# Cache info
_infocache =
	tracks: {}
	albums: {}
	artists: {}

# Which codec will we be using?
_codec = null

_draggingseekbar = false

# Convenient shortcuts
setTimeout = (t, f) -> window.setTimeout f, t
setInterval = (t, f) -> window.setInterval f, t
log = -> console.log.apply console, arguments if console?.log?
$$ = (s) -> $(s).toArray()


# localStorage wrapper
store =
	get: (k) -> JSON.parse localStorage.getItem(k)
	set: (k, v) -> localStorage.setItem k, JSON.stringify(v)
	init: (k, v) -> localStorage.setItem k, JSON.stringify(v) unless localStorage.getItem k


# Escape HTML entities
String.prototype.quote = ->
	this
		.replace(/</g, '&lt')
		.replace(/>/g, '&gt')
		.replace(/&/g, '&amp;')
		.replace(/"/g, '&quot;')
		.replace(/'/g, '&apos;')
		.replace(/\//g, '&#x2f;')


String.prototype.toNum = -> parseInt this, 10


# Find the first element matching sel
jQuery.fn.findNext = (sel, num=1, _prev=false) ->
	ref = if _prev then $(this).prev() else $(this).next()
	while true
		return false if ref.length is 0
		arewe = ref.is sel
		num -= 1 if arewe
		return ref if arewe and num is 0
		ref = if _prev then ref.prev() else ref.next()
jQuery.fn.findPrev = (sel, num=1) -> this.findNext sel, num, true


# Init library pane
initLibrary = ->
	$('#library ol').scrollbar
		wheelSpeed: 150

	# Toggle artist open/close
	toggleArtist = (elem) ->
		elem = elem.closest 'li'
		return unless elem.is '.artist'
		n = elem.next()
		while true
			break unless n.hasClass 'album'
			if n.css('display') is 'block'
				n.css 'display', 'none'
				elem.find('i').attr 'class', 'icon-expand-alt'
			else
				n.css 'display', 'block'
				elem.find('i').attr 'class', 'icon-collapse-alt'
			n = n.next()

		$('#library ol').scrollbar 'update'

	# Select artist/album
	selectLRow = (elem) ->
		return false unless elem
		$('#library .active').removeClass 'active'
		elem.closest('li').addClass 'active'

		if elem.position().top > $('#library ol').height() or elem.position().top < 0
			$('#library ol')[0].scrollTop += elem.closest('li').position().top
			$('#library ol').scrollbar 'update'

	# Add album to playlist
	addAlbum = (elem) ->
		addAlbumToPlaylist elem.closest('li').attr('data-id')

	# Select the first row on page load
	# TODO: Perhaps remember last
	selectLRow $('#library li:first')

	# Various mouse binds
	$('#library ol').on 'click', 'li span', -> selectLRow $(this)
	$('#library ol').on 'click', '.artist i', -> toggleArtist $(this)
	$('#library ol').on 'dblclick', '.artist span', (e) ->
		e.preventDefault()
		selectLRow $(this)
		toggleArtist $(this)

	$('#library ol').on 'mousedown', '.artist span', (e) ->
		return unless e.button is 1
		e.preventDefault()
		selectLRow $(this)

		next = $(this).closest('li').next()
		while true
			break unless next.is('.album')
			addAlbum next
			next = next.next()

	$('#library ol').on 'mousedown', '.album span', (e) ->
		return unless e.button is 1
		e.preventDefault()
		selectLRow $(this)
		addAlbum $(this)

	$('#library ol').on 'dblclick', '.album span', (e) ->
		e.preventDefault()
		addAlbum $(this)

	# Filter
	# TODO: unicode, ie. `a' also matches `ä'
	t = null
	pterm = null
	filter = (e) ->
		clearTimeout t if t
		t = setTimeout 400, ->
			$(e.target).removeClass 'invalid'
			term = $(e.target).val().trim()
			return if term is pterm
			pterm = term
			if term is ''
				$('#library .artist').show()
				$('#library .album').hide()
				return

			try
				term = new RegExp term
			catch exc
				$(e.target).addClass 'invalid'
				return
			$('#library li').hide()
			$('#library ol')[0].scrollTop = 0
			$$('#library li').forEach (elem) ->
				elem = $(elem)
				if elem.text().toLowerCase().match term
					if elem.is('.artist')
						elem.show()
					else
						elem.findPrev('.artist').show()
			$('#library ol').scrollbar 'update'

	$('#search input').on 'keydown', filter
	$('#search input').on 'change', filter

	# Keybinds
	chain = ''
	timer = null
	cleartimer = null
	$('body').on 'keydown', (e) ->
		return if document.activeElement?.tagName?.toLowerCase() is 'input'
		return unless _activepane?.is '#library'
		return if e.ctrlKey or e.altKey

		events =
			27: -> # Esc
				clearTimeout timer if timer
				clearTimeout cleartimer if cleartimer
				chain = ''
				return
			38: -> selectLRow $('#library .active').findPrev 'li:visible' # Up
			40: -> selectLRow $('#library .active').findNext 'li:visible' # Down
			39: -> # Right
				act = $('#library .active')
				if act.is '.artist'
					if act.next().is(':visible')
						selectLRow act.next()
					else
						toggleArtist act
			37: -> # Left
				act = $('#library .active')
				if act.is('.album')
					selectLRow act.findPrev('.artist')
				else if act.is('.artist') and act.next().is(':visible')
					toggleArtist act
			33: -> # Page up
				n = Math.floor $('#library ol').height() / $('#library li:first').outerHeight()
				r = selectLRow $('#library .active').findPrev('li:visible', n)
				selectLRow $('#library li:first') if r is false
			34: -> # Page down
				n = Math.floor $('#library ol').height() / $('#library li:first').outerHeight()
				r = selectLRow $('#library .active').findNext('li:visible', n)
				selectLRow $('#library li:last') if r is false
			36: -> selectLRow $('#library li:first') # Home
			35: -> selectLRow $('#library li:last') # End
			13: -> # Enter
				act = $('#library .active')
				toggleArtist act if act.is('.artist')
				addAlbum act if act.is('.album')

		if events[e.keyCode]?
			e.preventDefault()
			events[e.keyCode]()
		# 0-9a-z & space
		# TODO: unicode, ie. `a' also matches `ä'
		else if e.keyCode is 32 or (e.keyCode > 46 and e.keyCode < 91)
			e.preventDefault()
			chain += String.fromCharCode(e.keyCode).toLowerCase()
			clearTimeout timer if timer
			timer = setTimeout 100, ->
				$('#library li').each (i, elem) ->
					elem = $(elem)
					if elem.is(':visible') and elem.text().toLowerCase().indexOf(chain) is 0
						selectLRow elem
						return false
			clearTimeout cleartimer if cleartimer
			cleartimer = setTimeout 3000, -> chain = ''


# Init playlist
initPlaylist = ->
	store.get('playlist').forEach (r) ->
		$('#playlist tbody').append r

	$('#playlist-wrapper').scrollbar
		wheelSpeed: 150

	# Set a row as active
	setRowActive = (row) ->
		row = $(row).closest 'tr'

		$('#playlist tr').removeClass 'active'
		row.addClass 'active'
		setInfo row.attr('data-id')

		if row.position().top > $('#playlist-wrapper').height() or row.position().top < 0
			$('#playlist-wrapper')[0].scrollTop += row.position().top
			$('#playlist-wrapper').scrollbar 'update'

	# Select a row in the playlist
	selectRow = (row, active=true) ->
		return false unless row
		row = $(row).closest 'tr'
		row.addClass 'selected'
		setRowActive row if active

	# Deselect a row ion the playlist
	deSelectRow = (row, active=true) ->
		row = $(row).closest 'tr'
		row.removeClass 'selected'
		setRowActive row if active

	# Select all rows from .active until `stop'
	selectRowsUntil = (stop, active=true) ->
		return false unless stop
		stop = $(stop).closest 'tr'
		row = $('#playlist .active')

		if row.length is 0
			selectRow stop, active
			return

		dir = if stop.index() > row.index() then 'next' else 'prev'
		while true
			selectRow row, false
			if row.is stop
				setRowActive row if active
				break
			row = if dir is 'next' then row.next() else row.prev()

	# Clear all selection
	clearSelection = ->
		$('#playlist tr').removeClass('selected').removeClass 'active'

	# Mouse
	$('body').on 'click', (e) ->
		return unless _activepane?.is '#playlist-wrapper'
		return if $(e.target).closest('tr').length is 1
		clearSelection()

	$('#playlist tbody').on 'click', 'tr', (e) ->
		if e.shiftKey
			selectRowsUntil this
		else if e.ctrlKey
			selectRow this
		else
			clearSelection()
			selectRow this

	$('#playlist tbody').on 'dblclick', 'tr', (e) ->
		clearSelection()
		selectRow this
		playRow this

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
			$('#playlist .selected').remove()
			savePlaylist()
		# Up arrow
		else if e.keyCode is 38
			e.preventDefault()
			r = $('#playlist .active')
			return selectRow $('#playlist tbody tr:last') if r.length is 0
			return if r.prev().length is 0
			if e.shiftKey
				if r.hasClass('selected') and r.prev().hasClass('selected')
					deSelectRow r
				selectRow r.prev()
			else if e.ctrlKey
				r.removeClass('active').prev().addClass('active')
			else
				clearSelection()
				selectRow r.prev()
		# Down arrow
		else if e.keyCode is 40
			e.preventDefault()
			r = $('#playlist .active')
			return selectRow $('#playlist tbody tr:first') if r.length is 0
			return if r.next().length is 0
			if e.shiftKey
				if r.hasClass('selected') and r.next().hasClass('selected')
					deSelectRow r
				selectRow r.next()
			else if e.ctrlKey
				r.removeClass('active').next().addClass('active')
			else
				clearSelection()
				selectRow r.next()
		# Page down
		else if e.keyCode is 34
			e.preventDefault()
			n = Math.floor $('#playlist-wrapper').height() / $('#playlist tr:last').outerHeight()
			if e.shiftKey
				r = selectRowsUntil $('#playlist .active').findNext('tr', n)
				selectRowsUntil $('#playlist tbody tr:last') if r is false
			else
				clearSelection()
				r = selectRow $('#playlist .active').findNext('tr', n)
				selectRow $('#playlist tbody tr:last') if r is false
		# Page up
		else if e.keyCode is 33
			e.preventDefault()
			n = Math.floor $('#playlist-wrapper').height() / $('#playlist tr:last').outerHeight()
			if e.shiftKey
				r = selectRowsUntil $('#playlist .active').findPrev('tr', n)
				selectRowsUntil $('#playlist tbody tr:first') if r is false
			else
				clearSelection()
				r = selectRow $('#playlist .active').findPrev('tr', n)
				selectRow $('#playlist tbody tr:first') if r is false
		# Home
		else if e.keyCode is 36
			e.preventDefault()
			if e.shiftKey
				selectRowsUntil $('#playlist tbody tr:first')
			else if e.ctrlKey
				$('#playlist .active').removeClass 'active'
				$('#playlist tbody tr:first').addClass 'active'
			else
				clearSelection()
				selectRow $('#playlist tbody tr:first')
		# End
		else if e.keyCode is 35
			e.preventDefault()
			if e.shiftKey
				selectRowsUntil $('#playlist tbody tr:last')
			else if e.ctrlKey
				$('#playlist .active').removeClass 'active'
				$('#playlist tbody tr:last').addClass 'active'
			else
				clearSelection()
				selectRow $('#playlist tbody tr:last')
		# Enter
		else if e.keyCode is 13
			e.preventDefault()
			$('#playlist .active').dblclick()

	# Sorting
	sort = null
	$('#playlist thead').on 'click', 'th', (e) ->
		h = $(this)

		psort = null
		if $('#playlist thead').find('.icon-sort-up').length > 0
			psort = $('#playlist thead').find('.icon-sort-up').parent()
		else if $('#playlist thead').find('.icon-sort-down').length > 0
			psort = $('#playlist thead').find('.icon-sort-down').parent()

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
		savePlaylist()


# Set info to trackId
setInfo = (trackId) ->
	set = (track) ->
		album = _infocache['albums'][track.album]
		artist = _infocache['artists'][album.artist]

		$('#info img').one 'load', ->
			$('#info .table-wrapper').width $('#info').width() - $('#info img').width() - 20
		$('#info img').attr 'src', album.coverdata

		$('#info tbody').html('').append """
			<tr>
				<th>Artist name</th>
				<td>#{artist.name.quote() or '[Unknown]'}</td>
			</tr>
			<tr>
				<th>Album title</th>
				<td>#{album.name.quote() or '[Unknown]'}</td>
			</tr>
			<tr>
				<th>Track title</th>
				<td>#{track.name.quote() or '[Unknown]'}</td>
			</tr>
			<tr>
				<th>Released</th>
				<td>#{track.released or '[Unknown]'}</td>
			</tr>
			<tr>
				<th>Track number</th>
				<td>#{track.trackno or '[Unknown]'}</td>
			</tr>
			<tr>
				<th>Total tracks</th>
				<td>#{album.numtracks or '[Unknown]'}</td>
			</tr>
			<tr>
				<th>Disc number</th>
				<td>#{track.discno or '[Unknown]'}</td>
			</tr>
			<tr>
				<th>Total discs</th>
				<td>#{album.numdiscs or '[Unknown]'}</td>
			</tr>
			<tr>
				<th>Length</th>
				<td>#{displaytime track.length or '[Unknown]'}</td>
			</tr>
			<tr>
				<th>Filename</th>
				<td>#{track.path.split('/').pop().quote()}</td>
			</tr>
			<tr>
				<th>Directory</th>
				<td>#{track.path.split('/')[..-2].join('/').quote()}</td>
			</tr>
		"""

	if _infocache['tracks'][trackId]?
		set _infocache['tracks'][trackId]
	else
		_inforeq.abort() if _inforeq
		_inforeq = jQuery.ajax
			url: "#{_root}/get-track/#{trackId}"
			type: 'get'
			dataType: 'json'
			#error: (req, st) -> alert req.responseText if st isnt 'abort'
			success: (data) ->
				_inforeq = null
				# TODO Clear old items from cache at some point
				_infocache['artists'][data.artist.id] = data.artist
				_infocache['albums'][data.album.id] = data.album
				_infocache['tracks'][data.track.id] = data.track

				set data.track


# Try and play the next track
playNext = (prev=false) ->
	n = if prev then $('#playlist .playing').prev() else $('#playlist .playing').next()
	$('#playlist .playing').removeClass 'playing'
	if n.length > 0
		playRow n
		return true
	else
		return false


# Try and play the previous track
playPrev = -> playNext true


# Init. the player
# We also update the statusbar here for efficiency
initPlayer = ->
	bufstart = null

	$('#player').on 'click', '.play', (e) ->
		if isNaN(_audio.duration)
			active = $('#playlist .active')
			return playRow active if active.length > 0
			return playRow $('#playlist tbody tr:eq(0)')
		_audio.play()

	$('#player').on 'click', '.pause', (e) -> _audio.pause()
	$('#player').on 'click', '.forward', (e) -> playNext()
	$('#player').on 'click', '.backward', (e) -> playPrev()

	$('#player').on 'click', '.stop', (e) ->
		$('.seekbar .buffer').css 'width', '0px'
		_audio.pause()
		$('#playlist tr').removeClass 'playing'
		_audio.src = ''
		$('#player').attr 'class', 'right-of-library stopped'
		store.set 'lasttrack', null
		bufstart = null
		$('#status span:eq(0)').html 'Stopped'

	window.vol = new Slider
		target: $('#player .volume')
		move: (pos) ->
			v = Math.min 1, pos * 2 / 100
			_audio.volume = v
			store.set 'volume', v
			return Math.round pos

	if store.get('volume') isnt null
		_audio.volume = store.get 'volume'
		vol.setpos _audio.volume * 100
	else
		vol.setpos 50
		_audio.volume = 0.5

	seekbar = new Slider
		target: $('#player .seekbar')
		start: -> _draggingseekbar = true
		move: (pos) ->
			v = $('audio')[0].seekable.end(0) / 100 * pos
			$('audio')[0].currentTime = v
			return displaytime v
		stop: -> _draggingseekbar = false

	$(_audio).bind 'play', ->
		$('#player').attr 'class', 'right-of-library playing'
		$('#playlist .playing .icon-pause').attr 'class', 'icon-play'

	$(_audio).bind 'pause', ->
		$('#player').attr 'class', 'right-of-library paused'
		$('#playlist .playing .icon-play').attr 'class', 'icon-pause'
		$('#status span:eq(0)').html 'Paused'

	$(_audio).bind 'ended', ->
		$('.seekbar .buffer').css 'width', '0px'
		bufstart = null
		unless playNext()
			$('#player').attr 'class', 'right-of-library stopped'
			store.set 'lasttrack', null
			$('#status span:eq(0)').html 'Stopped'

	$(_audio).bind 'timeupdate', (e) ->
		return if _draggingseekbar
		v = _audio.currentTime / _curplaying.length * 100
		seekbar.setpos v

		t = displaytime _audio.currentTime
		$('#status span:eq(0)').html 'Playing'
		$('#status span:eq(1)').html "#{t} / #{displaytime _curplaying.length}"

	$(_audio).bind 'progress', (e) ->
		try
			c = Math.round(_audio.buffered.end(0) / _curplaying.length * 100)
		catch exc
			return

		if c is 100
			$('#status span:eq(2)').html "Buffer #{c}%"
		else
			unless bufstart
				bufstart = new Date().getTime() / 1000
				return

			dur = (new Date().getTime() / 1000 - bufstart)
			r = (dur / c) * (100 - c)

			$('#status span:eq(2)').html "Buffer #{c}% (~#{Math.round r}s remaining)"

	$(_audio).bind 'progress', (e) ->
		try
			v = _audio.buffered.end(0) / _curplaying.length * 100
		catch exc
			return
		$('.seekbar .buffer').css 'width', "#{v}%"


class Slider
	constructor: (opt) ->
		@opt = opt
		my = this

		opt.target = $(opt.target)
		opt.target.addClass 'slider'
		opt.target.append '<span class="slider-bar"></span>'
		opt.target.append '<span class="slider-handle"></span>'

		@bar = opt.target.find '.slider-bar'
		@handle = opt.target.find '.slider-handle'

		tooltip = null
		setpos = (e) ->
			left = e.pageX - my.bar.offset().left - my.handle.width()
			max = my.bar.width() - my.handle.width()
			left = 0 if left < 0
			left = max if left > max

			my.handle.css 'left', "#{left}px"
			tip = my.opt.move my.getpos() if my.opt.move
			if tip?
				if tooltip is null
					$(my.opt.target).append "<span id='tooltip'></span>"
					tooltip = $('#tooltip')
				tooltip.html tip
				tooltip.css 'left', "#{left - 20}px"

		stop = ->
			my.opt.stop() if my.opt.stop
			$('#tooltip').remove()
			tooltip = null

		start = -> my.opt.start() if my.opt.start

		@bar.bind 'click', setpos
		babyUrADrag @handle, start, setpos, stop


	# Get position as percentage 0-100
	getpos: ->
		@handle.css('left').toNum() / ((@bar.width() - @handle.width()) / 100)


	# Set position as percentage 0-100
	setpos: (p) ->
		@handle.css 'left', "#{(@bar.width() - @handle.width()) / 100 * p}px"


# Add album to playlist
addAlbumToPlaylist = (albumId) ->
	jQuery.ajax
		url: "#{_root}/get-album/#{albumId}"
		type: 'get'
		dataType: 'json'
		#error: (req, st) -> alert req.responseText if st isnt 'abort'
		success: (data) ->
			pl = $('#playlist tbody')
			save = []
			for t in data.tracks
				row = """<tr data-id="#{t.id}" data-length="#{t.length}">
					<td></td>
					<td>#{t.discno}.#{if t.trackno < 10 then 0 else ''}#{t.trackno}</td>
					<td>#{data.artistname.quote()} - #{data.name.quote()}</td>
					<td>#{t.name.quote()}</td>
					<td>#{displaytime t.length}</td>
				</tr>"""

				pl.append row
				save.push row
			$('#playlist-wrapper').scrollbar 'update'
			store.set 'playlist', store.get('playlist').concat save


# Formats seconds as min:sec
displaytime = (sec) ->
	m = Math.floor sec / 60
	s = Math.floor sec % 60
	return "#{m}:#{if s < 10 then 0 else ''}#{s}"


# Play audio file `trackId` of `length` seconds
play = (trackId, length) ->
	return if _codec is null

	jQuery.ajax
		url: "#{_root}/play-track/#{_codec}/#{trackId}"
		type: 'get'
		dataType: 'json'
		#error: (req, st) -> alert req.responseText if st isnt 'abort'
		success: (data) ->
			_curplaying =
				trackId: trackId
				length: length

			audio = $('#player audio')[0]
			audio.pause()
			audio.src = ''
			audio.src = data.src
			audio.play()

	row = $("#playlist tr[data-id=#{trackId}]")
	$('#playlist tr').removeClass 'playing'
	row.addClass('playing').find('td:eq(0)').html '<i class="icon-play"></i>'
	store.set 'lasttrack', trackId


# Play this table row
playRow = (r) -> play $(r).attr('data-id'), $(r).attr('data-length')

# Init. the resize handlers for the various panes
initPanes = ->
	setPane = (p) ->
		_activepane = $(p)
		$('.pane-active').removeClass 'pane-active'
		_activepane.addClass 'pane-active'

	$('body').on 'click', '#library', -> setPane this
	$('body').on 'click', '#playlist-wrapper', -> setPane this
	$('body').on 'click', '#player', -> setPane this
	$('body').on 'click', '#info', -> setPane this

	$('body').on 'keydown', (e) ->
		if e.keyCode is 27
			e.preventDefault()
			_activepane = null
			$('.pane-active').removeClass 'pane-active'

	setinfo = (h, set) ->
		set.css 'height', "#{h}px"
		$('#info .table-wrapper').css 'height', "#{h}px"
		$('#playlist-wrapper').css 'bottom', "#{h + $('#status').height() + 3}px"
		$('#playlist-wrapper').scrollbar 'update'
		$('#info .table-wrapper').scrollbar 'update'
		$('#info .table-wrapper').width $('#info').width() - $('#info img').width() - 20

	setlib = (w, set) ->
		set.css 'width', "#{w}px"
		$('.right-of-library').css 'left', "#{$('#library').width()}px"

	$('.resize-handle').each (i, elem) ->
		elem = $(elem)
		set = elem.parent()

		if elem.hasClass('resize-vertical')
			setinfo store.get('info-size'), set if store.get('info-size')
		else
			setlib store.get('library-size'), set if store.get('library-size')

		move = (e) ->
			# info
			if elem.hasClass('resize-vertical')
				setinfo $(window).height() - e.pageY - $('#status').height(), set
			# library
			else
				setlib e.pageX, set

		stop = ->
			if elem.hasClass('resize-vertical')
				store.set 'info-size', $('#info').height()
			else
				store.set 'library-size', $('#library').width()

		babyUrADrag elem, null, move, stop

# Drag & drop
babyUrADrag = (handle, start, move, end) ->
	dragging = false

	mousemove = (e) ->
		return unless dragging
		setSize()
		move?.apply this, [e]

	mousedown = (e) ->
		handle.addClass 'dragging'
		dragging = true
		$(handle).css 'z-index', '99'
		document.body.focus()
		start?.apply this, [e]

		return false

	mouseup = (e) ->
		handle.removeClass 'dragging'
		dragging = false
		end?.apply this, [e]

	handle.on 'mousedown', mousedown
	$('body').on 'mousemove', mousemove
	$('body').on 'mouseup', mouseup


# Init. info pane
initInfo = ->
	$('#info .table-wrapper').scrollbar
		wheelSpeed: 150


# Try and detect if we support the user's browser, and warn if we (probably) don't
detectSupport = ->
	err = []
	unless window.JSON?.parse
		err.push "Your browser doesn't seem to support JSON"
	unless window.localStorage?.setItem
		err.push "Your browser doesn't seem to support localStorage"

	if _audio.canPlayType('audio/ogg; codecs="vorbis"') isnt ''
		_codec = 'ogg'
	else if _audio.canPlayType('audio/mp3; codecs="mp3"') isnt ''
		_codec = 'mp3'
	else
		err.push "Your browser doesn't seem to support either Ogg/Vorbis or MP3 playback"

	# TODO: We can do better than an alert()
	alert err.join '\n' if err.length > 0


# Dynamicly set various sizes (stuff we can't CSS)
setSize = ->
	# We need a fixed height for the scrollbar to work
	$('#library ol').css 'height', "#{$(window).height() - $('#library ol').offset().top}px"

	$('.seekbar').css 'width', "#{$('#player').width() - $('.volume').outerWidth() - $('.volume').position().left - 30}px"
	$('#playlist-wrapper').css 'bottom', "#{$('#info').height() + $('#status').height() + 3}px"
	$('#info .table-wrapper').width $('#info').width() - $('#info img').width() - 20

# Save the playlist to localStorage
savePlaylist = ->
	store.set 'playlist', $$('#playlist tbody tr').map (r) -> r.outerHTML


$(document).ready ->
	detectSupport()

	# Reset inputs on page refresh
	$('input').val ''

	store.init 'playlist', []

	setSize()

	initPlayer()
	initLibrary()
	initInfo()
	initPlaylist()
	initPanes()

	setSize()
	$(window).on 'resize', setSize

	playRow $("#playlist tr[data-id=#{store.get('lasttrack')}]") if store.get('lasttrack')?


# The MIT License (MIT)
#
# Copyright © 2013 Martin Tournoij
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# The software is provided "as is", without warranty of any kind, express or
# implied, including but not limited to the warranties of merchantability,
# fitness for a particular purpose and noninfringement. In no event shall the
# authors or copyright holders be liable for any claim, damages or other
# liability, whether in an action of contract, tort or otherwise, arising
# from, out of or in connection with the software or the use or other dealings
# in the software.
