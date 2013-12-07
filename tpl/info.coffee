# Init. info pane
window.Info = class Info
	# jQuery request to fetch info
	_req: null


	###
	###
	constructor: ->
		$('#info .table-wrapper').scrollbar
			wheelSpeed: 150

		$('#info').on 'click', 'img', (e) ->
			img = $(this)
			return if img.attr('src') is ''

			$('body').append """<div id='large-cover'>
				<img src='#{img.attr 'src'}' alt=''>
			</div>"""

			$('#large-cover')
				.css
					width: "#{img.width()}px"
					height: "#{img.height()}px"
				.animate {
					width: '100%'
					height: '100%'
				}, {
					duration: 500
				}

			$('#large-cover').one 'click', (e) ->
				$(this).animate {
					width: "#{img.width()}px"
					height: "#{img.height()}px"
				}, {
					complete: => $(this).remove()
					duration: 500
				}


	###
	###
	getInfo: (trackId) ->
		track = _cache.tracks[trackId]

		return [null, null, null] unless track?

		album = _cache.albums[track.album]
		artist = _cache.artists[album.artist]

		return [track, album, artist]

	###
	###
	clear: ->
		$('#info img').attr 'src', ''
		$('#info tbody').html ''


	###
	Set info to trackId
	###
	setTrack: (trackId) ->
		if window._cache['tracks'][trackId]?
			@_set window._cache['tracks'][trackId]
			return

		my = this
		@_req.abort() if @_req
		@_req = jQuery.ajax
			url: "#{_root}/get-album-by-track/#{trackId}"
			type: 'get'
			dataType: 'json'
			#error: (req, st) -> alert req.responseText if st isnt 'abort'
			success: (data) =>
				@_req = null
				window._cache['artists'][data.artist.id] = data.artist
				window._cache['albums'][data.album.id] = data.album

				for t in data.tracks
					window._cache['tracks'][t.id] = t
					my._set t if t.id is trackId.toNum()


	###
	###
	_set: (track) ->
		album = window._cache['albums'][track.album]
		artist = window._cache['artists'][album.artist]

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
