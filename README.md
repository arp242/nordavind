Nordavind is a web based audio player. The idea is that you can play your music
collection at home anywhere.

The UI is inspired by foobar2000, or rather, my particular foobar2000 setup
(Nordavind doesn’t offer the *extreme* flexibility that foobar2000 has).

For a general impression, check out the [screenshots](https://bitbucket.org/Carpetsmoker/nordavind/wiki/Home)


Browser support
===============
**Nordavind works best in Firefox**, other current browsers (Opera, Chrome, IE10)
also work, but all experience minor issues. At the moment adding features,
tweaking the interface, and fixing real bugs is a higher priority than dealing
with various browser quirks (Firefox just happens to be the only browser that
works without fizzle).

Browsers that will *never-ever* work are Internet Explorer 8 and Safari 5.


Audio codecs
------------
Nordavid uses the HTML5 `<audio>` element, while all current browsers support
this quite well, there are some difference, notably, in the supported codecs.

- Firefox and Opera will play Ogg Vorbis files
- Internet Explorer and Safari will play MP3 files
- Chrome will play both

Nordavind will transparently convert files for you, but you should be aware that
converting from MP3 to Ogg Vorbis (or vice versa) *will* reduce audio quality
even at fairly high bitrates because you’re converting from one lossless format
to another. So you may want to choose your browser depending on the format of
you music collection.

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
You almost certainly want to edit `config.cfg` and edit at least the `password`
and `musicpath` options.


Running
-------
Run `serve.py` to start the server. You can optionally add an `address:port`
to listen on (defaults to `0.0.0.0:8001`).

Note that Nordavind only supports a single user; you can’t use the same
installation with multiple users.


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


Using Nordavind
===============
A pane (library, playlist, player, info) needs to have focus for it to receive
keybinds.


Global
------
- The tab key cycles focus between playlist, library, filter, and the player
  buttons


Library
-------
- Doubleclicking an artist will open/close it

- Doubleclicking an album will append it to the playlist

- Middleclicking either an artist or album will append it to the playlist (note
  that there's no reliable way to prevent the default action on middle click, so
  this may do unexpected things)

- Typing any text while the library is focused will highlight whatever you’re
  typing (similar to many native desktop applications)


Playlist
--------
- You can select multiple rows with the shift & ctrl modifier keys

- Arrow keys, page{up,down}, home, and end all work as expected.

- ctrl+a selects everything


Info
----
- Click on the album to get a larger view


Player
------
Nothing yet...


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
