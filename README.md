Nordavind is a web based audio player. The idea is that you can play your music
collection at home anywhere.

The UI is inspired by foobar2000, or rather, my particular foobar2000 setup,
since Nordavind doesn’t offer the extreme flexibility that foobar2000 has.


Browser support
===============
Nordavind should work in all current browser versions. Examples of olders
browsers that will *not* work are Internet Explorer 8 and Safari 5.

In particular, I’ve tested Opera 12 and Firefox 23 on Windows & FreeBSD.
I did some basic testing with Chrome 29 and IE10, which seem to work okay.

Note that (most) smartphones & tablets won’t work very well at the moment,
problems include reliance on double/middleclicking, awkward scrolling, and
window size. Some works needs to be done here.


Audio codecs
------------
Nordavid uses the HTML5 `<audio>` capability, while all current browsers support
this quite well, there are some difference, notably, in the supported codecs.

- Firefox and Opera will play Ogg Vorbis files
- Internet Explorer and Safari will play MP3 files
- Chrome will play both

Nordavind will transparently convert this for you, but you should be aware that
converting from MP3 to Ogg Vorbis (or vice versa) *will* reduce audio quality
even at high bitrates because you’re converting from one lossless format to
another. So you may want to choose your browser depending on the format of you
music collection.

Note that converting FLAC to either format is fine.


Installation
============

Dependencies
------------
- A UNIX/Linux machine (Windows will not work)
- [Python 3](http://python.org/) (Python 2 will not work)
- [Jinja2](http://jinja.pocoo.org/docs/)
- py-sqlite3 (Included in Python, sometimes a separate package)
- [pytaglib](https://pypi.python.org/pypi/pytaglib)
- [CherryPy](http://www.cherrypy.org/)


### Optional
- If you want to convert from FLAC to Ogg Vorbis: [`flac`][flac] and [`oggenc`][vorbis]
- If you want to convert from FLAC to MP3: [`flac`][flac] and [`lame`][lame]
- If you want to convert from MP3 to Ogg Vorbis: [`mpg123`][mpg123] and [`oggenc`][vorbis]
- If you want to convert from Ogg Vorbis to MP3: [`oggdec`][vorbis] and [`lame`][lame]

[flac]: http://xiph.org/flac/
[vorbis]: http://www.vorbis.com/
[mpg123]: http://mpg123.org/
[lame]: http://lame.sourceforge.net/


Configuration
-------------
TODO


Running
-------
Run `serve.py` to start the server. You can optionally add an `address:port`
to listen on (defaults to `0.0.0.0:8001`).


Security
--------
TODO


Adding your music collection
============================
There are two scripts to update your music collection:

- `update.py` Does a full update (add new track, update existing, and remove
  deleted tracks)
- `addnew.py` Only add new tracks; this is significantly faster

Both scripts accept a single argument, which is a directory in your _musicdir_,
if given, only that directory will be updated.

These scripts may give harmless warnings; they're from taglib, You can safely
ignore them (doesn't seem like they can can be disabled...)


Changelog
=========
Version 1.0, TODO
-----------------
- Initial release


Credits
=======
Copyright © 2013 Martin Tournoij <martin@arp242.net>  
MIT license applies

Nordavind includes (in whole, or code based on):

- [Bootstrap](http://getbootstrap.com/)
- [Font awesome](http://fortawesome.github.io/Font-Awesome/)
- [jQuery](http://jquery.com/)
- [jQuery.mousewheel](http://brandonaaron.net)
- [Perfect Scrollbar](http://github.com/noraesae)
