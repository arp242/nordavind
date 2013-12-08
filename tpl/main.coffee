#
# http://code.arp242.net/nordavind
#
# Copyright © 2013 Martin Tournoij <martin@arp242.net>
# See below for full copyright
#


# Script root
window._root = ''

# Current active pane
window._activepane = null

# Cache info
window._cache =
	tracks: {}
	albums: {}
	artists: {}


setPane = (p) ->
	window._activepane = $(p)
	$('.pane-active').removeClass 'pane-active'
	window._activepane.addClass 'pane-active'

# Init. the resize handlers for the various panes
initPanes = ->
	$('body').on 'click', '#library', -> setPane this
	$('body').on 'click', '#playlist-wrapper', -> setPane this
	$('body').on 'click', '#player', -> setPane this
	$('body').on 'click', '#info', -> setPane this

	$('body').on 'keydown', (e) ->
		if e.keyCode is 27
			e.preventDefault()
			window._activepane = null
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

		# A bit less `flicker' on page load
		elem.css 'display', 'block'


# Try and detect if we support the user's browser, and warn if we (probably)
# don't
detectSupport = ->
	err = []
	unless window.JSON?.parse
		err.push "Your browser doesn't seem to support JSON"
	unless window.localStorage?.setItem
		err.push "Your browser doesn't seem to support localStorage"

	if new Audio().canPlayType('audio/ogg; codecs="vorbis"') isnt ''
		window.player.codec = 'ogg'
	else if new Audio().canPlayType('audio/mp3; codecs="mp3"') isnt ''
		window.player.codec = 'mp3'
	#else
	#	err.push "Your browser doesn't seem to support either Ogg/Vorbis or MP3 playback"

	# TODO: We can do better than an alert()
	alert err.join '\n' if err.length > 0


# Dynamicly set various sizes (stuff we can't CSS)
window.setSize = ->
	# We need a fixed height for the scrollbar to work
	$('#library ol').css 'height', "#{$(window).height() - $('#library ol').offset().top}px"

	$('.seekbar').css 'width', (
		$('#player').width() -
		$('.volume').outerWidth() -
		$('.volume').position().left -
		$('.buttons-right').outerWidth() -
		30
	) + 'px'
	$('#playlist-wrapper').css 'bottom', "#{$('#info').height() + $('#status').height() + 3}px"
	$('#info .table-wrapper').width $('#info').width() - $('#info img').width() - 20

	$('#playlist-thead').css 'left', "#{$('#playlist').offset().left}px"
	window.playlist.headSize() if window.playlist?.headSize?


initGlobalKeys = ->
	cycle = ['#library', '#playlist-wrapper', '#search input', '#player .play',
		'#player .pause', '#player .backward', '#player .forward', '#player .stop']

	$('body').on 'keydown', (e) ->
		return unless e.keyCode is 9

		e.preventDefault()

		active = null
		cycle.forEach (sel) ->
			active = sel if $(document.activeElement).is sel

		if active is null
			cycle.forEach (sel) ->
				active = sel if $('.pane-active').is sel

		if active is null
			setPane $('#library')
		else
			n = cycle.indexOf(active) + 1
			n = 0 if n > cycle.length - 1

			# This is a hack for the pause/play button
			n += 1 unless $(cycle[n]).is ':visible'

			$(active).blur()
			$('.pane-active').removeClass 'pane-active'
			window._activepane = null

			if $(cycle[n]).hasClass('pane')
				setPane $(cycle[n])
			else
				$(cycle[n]).focus()


$(document).ready ->
	# Reset inputs on page refresh
	$('input').val ''

	store.init 'client', md5(new Date() + Math.random())
	store.init 'playlist', []
	store.init 'replaygain', 'album'

	setSize()

	window.library = new Library()
	window.playlist = new Playlist()
	window.player = new Player()
	window.info = new Info()

	detectSupport()
	initPanes()
	initGlobalKeys()

	setSize()
	$(window).on 'resize', setSize
	window.playlist.headSize()

	window.playlist.playRow $("#playlist tr[data-id=#{store.get('lasttrack')}]") if store.get('lasttrack')?


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
