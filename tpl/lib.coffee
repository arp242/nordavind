# Convenient shortcuts
window.log = -> console.log.apply console, arguments if console?.log?
window.$$ = (s) -> $(s).toArray()
String.prototype.toNum = -> parseInt this, 10
Number.prototype.toNum = -> parseInt this, 10
jQuery.fn.replaceHTML = (s, r) -> this.html(this.html().replace s, r)


Function.prototype.timeout = (time, args) ->
	this.timeoutId = setTimeout =>
		this.apply this, args
	, time
Function.prototype.clearTimeout = -> clearTimeout this.timeoutId


Function.prototype.interval = (time, args) ->
	this.intervalId = setInterval =>
		this.apply this, args
	, time
Function.prototype.clearInterval = -> clearInterval this.intervalId


# Escape HTML entities
String.prototype.quote = ->
	this
		.replace(/</g, '&lt')
		.replace(/>/g, '&gt')
		.replace(/&/g, '&amp;')
		.replace(/"/g, '&quot;')
		.replace(/'/g, '&apos;')
		.replace(/\//g, '&#x2f;')




# Transliterate to 7-bit ascii characters
String.prototype.translit = (str) ->


# Find the first element matching sel
jQuery.fn.findNext = (sel, num=1, _prev=false) ->
	ref = if _prev then this.prev() else this.next()
	while true
		return false if ref.length is 0
		arewe = ref.is sel
		num -= 1 if arewe
		return ref if arewe and num is 0
		ref = if _prev then ref.prev() else ref.next()
jQuery.fn.findPrev = (sel, num=1) -> this.findNext sel, num, true


# localStorage wrapper
window.store =
	get: (k) -> JSON.parse localStorage.getItem("nordavind_#{k}")
	set: (k, v) -> localStorage.setItem "nordavind_#{k}", JSON.stringify(v)
	del: (k) -> localStorage.removeItem "nordavind_#{k}"
	init: (k, v) -> localStorage.setItem "nordavind_#{k}", JSON.stringify(v) unless localStorage.getItem "nordavind_#{k}"


# Formats seconds as min:sec
window.displaytime = (sec) ->
	m = Math.floor sec / 60
	s = Math.floor sec % 60
	return "#{m}:#{if s < 10 then 0 else ''}#{s}"


# Drag & drop
window.babyUrADrag = (handle, start, move, end) ->
	dragging = false

	mousemove = (e) ->
		return unless dragging
		setSize()
		move?.apply this, [e]

	origzindex = $(handle).css 'z-index'
	mousedown = (e) ->
		handle.addClass 'dragging'
		dragging = true
		$(handle).css 'z-index', '99'
		document.body.focus()
		e.preventDefault()
		start?.apply this, [e]

	mouseup = (e) ->
		handle.removeClass 'dragging'
		dragging = false
		$(handle).css 'z-index', origzindex
		end?.apply this, [e]

	handle.on 'mousedown', mousedown
	$('body').on 'mousemove', mousemove
	$('body').on 'mouseup', mouseup


window.Slider = class Slider
	constructor: (opt) ->
		@opt = opt
		my = this

		opt.target = $(opt.target)
		opt.target.addClass 'slider'
		h = opt.target.html()
		opt.target.html ''
		opt.target.append "<span class='slider-bar'>#{h}</span>"
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

		@bar.bind 'click', (e) ->
			start()
			setpos e
			stop()
		babyUrADrag @handle, start, setpos, stop


	# Get position as percentage 0-100
	getpos: ->
		@handle.css('left').toNum() / ((@bar.width() - @handle.width()) / 100)


	# Set position as percentage 0-100
	setpos: (p) ->
		@handle.css 'left', "#{(@bar.width() - @handle.width()) / 100 * p}px"
