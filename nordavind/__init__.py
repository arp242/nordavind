#!/usr/bin/env python3
# encoding:utf-8
#
# http://code.arp242.net/nordavind
#
# Copyright © 2013 Martin Tournoij <martin@arp242.net>
# See below for full copyright
#

import os, re, sys, urllib.parse, sqlite3, base64, glob, io

import taglib, unidecode
try:
	from PIL import Image
except ImportError:
	Image = None

import nordavind.audio


_root = os.path.dirname(os.path.realpath(sys.argv[0]))
_wwwroot = ''
config = None


def openDb(create=True):
	db = sqlite3.connect(config['dbpath'],
		detect_types=sqlite3.PARSE_DECLTYPES | sqlite3.PARSE_COLNAMES)

	if create and len(db.cursor().execute('select * from sqlite_master where type="table"').fetchall()) == 0:
		createDb()

	def dict_factory(cursor, row):
		d = {}
		for i, col in enumerate(cursor.description):
			d[col[0]] = row[i]
		return d
	db.row_factory = dict_factory

	return db


def template(f, v={}):
	from jinja2 import Environment, FileSystemLoader

	env = Environment(loader=FileSystemLoader('%s/tpl' % _root))
	env.filters['urlencode'] = lambda s: urllib.parse.quote_plus(s, '')

	return re.sub(r'>\s*<', '><', env.get_template(f).render(**v))


def createDb():
	db = openDb(False)
	c = db.cursor()

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
		rg_gain real,
		rg_peak real,
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
		rg_gain real,
		rg_peak real,
		foreign key(album) references albums(id) on delete cascade
	)''')

	c.execute('create unique index uniquepath on tracks (path)')
	c.execute('create unique index uniquealbum on albums (artist, name)')

	db.commit()


def addOrUpdateTrack(path):
	db = openDb()
	c = db.cursor()

	tags = getTags(path)
	track = c.execute('select * from tracks where path = ?',
		(path,)).fetchone()

	# Add track
	if track is None:
		album = c.execute('select * from albums where name = ?',
			(tags.get('album'),)
		).fetchone()

		# Add album
		if album is None:
			a = tags.get('albumartist')
			if not a: a = tags.get('artist')

			artist = c.execute('select * from artists where name = ?',
				(a,)).fetchone()

			# Add artist
			if artist is None:
				c.execute('insert into artists (name) values (?)', (a,))
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

			c.execute('''insert into albums (artist, name, released, cover, numtracks, numdiscs, rg_gain, rg_peak)
				values(?, ?, ?, ?, ?, ?, ?, ?)''',
				(artist, tags.get('album'), tags.get('date', '').split('-')[0], cover, tags.get('tracktotal'),
				tags.get('disctotal'), float(tags.get('replaygain_album_gain', '0').replace('dB', '')), float(tags.get('replaygain_album_peak', 0))))
			album = c.lastrowid
		else:
			album = album['id']

		c.execute('insert into tracks (path, name, album, trackno, discno, length, rg_gain, rg_peak) values (?, ?, ?, ?, ?, ?, ?, ?)',
			(path, tags.get('title'), album, tags.get('tracknumber'), tags.get('discnumber'), tags.get('length'),
			float(tags.get('replaygain_track_gain', '0').replace('dB', '')), float(tags.get('replaygain_track_peak', 0))))
	# Update track
	else:
		c.execute('''update tracks set name = ?, trackno = ?, discno = ?, length = ? where id = ?''',
			(tags.get('title'), tags.get('tracknumber'), tags.get('discnumber'), tags.get('length'), track['id']))

	db.commit()


def getTags(path):
	# Sometimes this prints a (harmless) warning, AFAIK this can't be disabled :-/
	f = taglib.File(path)

	r = {}
	for k, v in f.tags.items():
		if k in ['DISCNUMBER', 'TRACKNUMBER']:
			v = [v[0].split('/')[0]]
		r[k.lower()] = v if len(v) > 1 else v[0]

	r['length'] = f.length
	return r


def getLibrary():
	c = openDb().cursor()

	r = []
	for a in c.execute('select * from artists').fetchall():
		r.append({
			'id': a['id'],
			'name': a['name'],
			'albums': c.execute('select * from albums where artist=? order by released',
				(a['id'],)).fetchall()
		})

		tr = unidecode.unidecode(a['name'])
		if tr != a['name']:
			r[len(r) - 1]['name_tr'] = tr

	r.sort(key=lambda k: (k.get('name_tr') or k['name']).lower())
	return r


def playTrack(client, codec, id):
	c = openDb().cursor()
	track = c.execute('select * from tracks where id=?', (id,)).fetchone()

	for buf in nordavind.audio.convert(client, id, track['path'], codec):
		yield buf


def getAlbum(id):
	c = openDb().cursor()

	album = c.execute('select * from albums where id=?', (id,)).fetchone()
	artist = c.execute('select * from artists where id=?', (album['artist'],)).fetchone()
	tracks = c.execute('select * from tracks where album=? order by discno, trackno', (album['id'],)).fetchall()

	if album['cover']:
		t = album['cover'].split('.').pop()
		if t == 'jpg': t = 'jpeg'

		if Image is not None:
			img = Image.open(album['cover'])
			img.thumbnail((800, 800), Image.ANTIALIAS)
			out = io.BytesIO()
			img.save(out, img.format)

			album['coverdata'] = 'data:image/%s;base64,%s' % (t,
				base64.b64encode(out.getvalue()).decode())
		else:
			if os.stat(album['cover']).st_size > 500 * 1024:
				album['coverdata'] = ''
			else:
				album['coverdata'] = 'data:image/%s;base64,%s' % (t,
					base64.b64encode(open(album['cover'], 'rb').read()).decode())
	else:
		album['coverdata'] = ''

	return {
		'artist': artist,
		'album': album,
		'tracks': tracks,
	}


def getAlbumByTrack(id):
	c = openDb().cursor()
	return getAlbum(c.execute('select * from tracks where id=?',
		(id,)).fetchone()['album'])



config = {}
for line in open('config.cfg').readlines():
	line = line.strip()
	if line == '' or line[0] == '#': continue

	k, v = line.split('=')
	k = k.strip()
	v = v.strip()

	if v == '': continue

	if k == 'dbpath': v = '%s/%s' % (_root, v)
	config[k] = v


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
