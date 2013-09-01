#!/usr/bin/env python3
# encoding:utf-8
#
# http://code.arp242.net/nordavind
#
# Copyright © 2013 Martin Tournoij <martin@arp242.net>
# See below for full copyright
#

import cgi, datetime, os, re, sys, traceback, urllib.parse, sqlite3
import _thread, time, shlex, subprocess, base64

from jinja2 import Environment, FileSystemLoader
import taglib


_root = os.path.dirname(os.path.realpath(sys.argv[0]))
_wwwroot = ''
_db = None
config = None


def OpenDb():
	global _db
	_db = sqlite3.connect(config['dbpath'],
		detect_types=sqlite3.PARSE_DECLTYPES | sqlite3.PARSE_COLNAMES)

	def dict_factory(cursor, row):
		d = {}
		for i, col in enumerate(cursor.description):
			d[col[0]] = row[i]
		return d
	_db.row_factory = dict_factory


def Template(f, v):
	env = Environment(loader=FileSystemLoader('%s/tpl' % _root))
	env.filters['urlencode'] = lambda s: urllib.parse.quote_plus(s, '')

	return re.sub(r'>\s*<', '><', env.get_template(f).render(**v))


def CreateDb():
	c = _db.cursor()

	c.execute('''create table artists (
		id integer primary key autoincrement,
		name text not null
	)''')

	c.execute('''create table albums (
		id integer primary key autoincrement,
		artist int not null,
		name text not null,
		released int,
		numdiscs int,
		numtracks int,
		cover text,
		foreign key(artist) references artists(id) on delete cascade
	)''')

	c.execute('''create table tracks (
		id integer primary key autoincrement,
		album int not null,
		name text not null,
		trackno int,
		discno int,
		length int,
		path text not null,
		foreign key(album) references albums(id) on delete cascade
	)''')

	c.execute('create unique index uniquepath on tracks (path)')
	c.execute('create unique index uniquealbum on albums (artist, name)')

	_db.commit()


def add_or_update_track(path):
	c = _db.cursor()
	track = c.execute('select * from tracks where path = ?',
		(path,)).fetchone()

	tags = gettags(path)
	# Add track
	if track == None:
		album = c.execute('select * from albums where name = ?',
			(tags.get('album'),)
		).fetchone()

		# Add album
		if album == None:
			a = tags.get('albumartist')
			if not a: a = tags.get('artist')

			artist = c.execute('select * from artists where name = ?',
				(a,)).fetchone()

			# Add artist
			if artist == None:
				c.execute('insert into artists (name) values (?)',
					(a,))
				artist = c.lastrowid
			else:
				artist = artist['id']

			cover = None
			for p in ['cover.jpg', 'cover.jpeg', 'cover.png', 'front.jpg', 'front.jpeg', 'front.png']:
				cover = '%s/%s' % (os.path.dirname(path), p)
				if os.path.exists(cover):
					break
				else:
					cover = None

			c.execute('insert into albums (artist, name, released, cover, numtracks, numdiscs) values(?, ?, ?, ?, ?, ?)',
				(artist, tags.get('album'), tags.get('date', '').split('-')[0], cover, tags.get('tracktotal'), tags.get('disctotal')))
			album = c.lastrowid
		else:
			album = album['id']

		c.execute('insert into tracks (path, name, album, trackno, discno, length) values (?, ?, ?, ?, ?, ?)',
			(path, tags.get('title'), album, tags.get('tracknumber'), tags.get('discnumber'), tags.get('length')))
	# Update track
	else:
		c.execute('''update tracks set name = ?, trackno = ?, discno = ?, length = ? where id = ?''',
			(tags.get('title'), tags.get('tracknumber'), tags.get('discnumber'), tags.get('length'), track['id']))

	_db.commit()


def gettags(path):
	r = {}
	# Sometimes this prints a (harmless) warning, AFAIK this can't be disabled
	# :-/
	f = taglib.File(path)
	for k, v in f.tags.items():
		if k in ['DISCNUMBER', 'TRACKNUMBER']:
			v = [v[0].split('/')[0]]
		r[k.lower()] = v if len(v) > 1 else v[0]

	r['length'] = f.length
	return r


def getlibrary():
	c = _db.cursor()

	r = []
	artists = c.execute('select * from artists order by name').fetchall()
	for a in artists:
		r.append({
			'id': a['id'],
			'name': a['name'],
			'albums': c.execute('select * from albums where artist=? order by released',
				(a['id'],)).fetchall()
		})

	return r


def getalbum(id):
	c = _db.cursor()

	album = c.execute('''select albums.*, artists.name as artistname from albums
		inner join artists on artists.id = albums.artist
		where albums.id=?''', (id,)).fetchone()
	album['tracks'] = c.execute('select * from tracks where album=? order by discno, trackno',
		(id,)).fetchall()

	return album


def playtrack(codec, id):
	c = _db.cursor()
	track = c.execute('select * from tracks where id=?', (id,)).fetchone()

	cache = '%s/%s.%s' % (config['cachepath'], re.sub(r'[^\w]', '', track['path']), codec)

	#if not os.path.exists(cache) or os.stat(cache).st_size == 0:
	src = '%s/stream-audio/%s/%s' % (
		_wwwroot,
		urllib.parse.quote_plus(track['path'].replace('/', '||')),
		urllib.parse.quote_plus(cache.replace('/', '||')))
	#else:
	#	src = cache.replace(_root, '')

	return {
		'src': src,
	}


def gettrack(id):
	c = _db.cursor()
	track = c.execute('select * from tracks where id=?', (id,)).fetchone()
	album = c.execute('select * from albums where id=?', (track['album'],)).fetchone()
	artist = c.execute('select * from artists where id=?', (album['artist'],)).fetchone()

	if album['cover']:
		t = album['cover'].split('.').pop()
		if t == 'jpg': t = 'jpeg'
		album['coverdata'] = 'data:image/%s;base64,%s' % (t,
			base64.b64encode(open(album['cover'], 'rb').read()).decode()
		)
	else:
		album['coverdata'] = ''

	return {
		'track': track,
		'album': album,
		'artist': artist,
	}


def streamaudio(path, cache=None):
	path = urllib.parse.unquote_plus(path.replace('||', '/'))
	codec = cache.split('.').pop()

	cache = None # TODO

	if cache != None:
		cache = urllib.parse.unquote_plus(cache.replace('||', '/'))

	#if cache != None and os.path.exists(cache):
	#	return open(cache, 'rb').read()

	t = path.split('.').pop()

	if codec == 'ogg':
		if t == 'flac':
			cmd = 'flac -sd %s -o -| oggenc - -q8 -Qo -' % shlex.quote(path)
		elif t == 'mp3':
			cmd = 'mpg123 -qw- %s| oggenc - -q8 -Qo -' % shlex.quote(path)
		elif t == 'ogg':
			cmd = 'cat'
			cache = None
	elif codec == 'mp3':
		if t == 'flac':
			cmd = 'flac -sd %s -o -| lame --quiet -V2 - -' % shlex.quote(path)
		elif t == 'ogg':
			cmd = 'oggdec -Qo- %s | lame --quiet -V2 - -' % shlex.quote(path)
		elif t == 'mp3':
			cmd = 'cat'
			cache = None

	p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE)

	if cache != None:
		cachefp = open(cache, 'wb')

	while True:
		buf = p.stdout.read(1024)
		if not buf: break
		if cache != None: cachefp.write(buf)
		yield buf


def start():
	OpenDb()
	if len(_db.cursor().execute('select * from sqlite_master where type="table"').fetchall()) == 0:
		CreateDb()


# TODO: Get from file
config = {
	'musicpath': '/data/music/',
	'dbpath': '%s/db/db.sqlite3' % _root,
	'cachepath': '/tmp/nordavind/',
}



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
