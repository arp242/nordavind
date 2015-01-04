#!/usr/bin/env python3
# encoding:utf-8
#
# http://code.arp242.net/nordavind
#
# Copyright © 2013-2015 Martin Tournoij <martin@arp242.net>
# See below for full copyright
#

import os, re, sys, urllib.parse, sqlite3, base64, glob, io, datetime
import unidecode

try:
	from PIL import Image
except ImportError:
	Image = None

import nordavind.audio, nordavind.update


_root = os.path.dirname(os.path.realpath(sys.argv[0]))
_wwwroot = ''
config = None


def openDb(create=True, read_only=False):
	# Python 3.4 and newer only
	#db = sqlite3.connect('file:{}{}'.format(config['dbpath'], '?mode=ro' if read_only else ''),
	#	uri=True, detect_types=sqlite3.PARSE_DECLTYPES | sqlite3.PARSE_COLNAMES)
	db = sqlite3.connect(config['dbpath'], detect_types=sqlite3.PARSE_DECLTYPES | sqlite3.PARSE_COLNAMES)

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

	env = Environment(loader=FileSystemLoader('{}/templates'.format(_root)))
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
		added_on text not null,
		rating int default 0 not null,
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

	c.execute('''create table searches (
		id integer primary key autoincrement,
		name text not null,
		search text not null
	)''')

	c.execute('create unique index unique_path on tracks (path)')
	c.execute('create unique index unique_album on albums (artist, name)')
	c.execute('create unique index unique_search on searches (name)')

	c.execute('''insert into searches (name, search) values
		("Recently added", "$ added_on > DATE('now', '-1 month') $"),
		("Rating = Unrated", "$ rating = 0 $"),
		("Rating => Crap", "$ rating >= 1 $"),
		("Rating => Meh", "$ rating >= 2 $"),
		("Rating => Okay", "$ rating >= 3 $"),
		("Rating = Super", "$ rating = 4 $")
	''')

	db.commit()


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

		# TODO: Can we also use unicodedate.normalize? Otherwise maybe iconv? I
		# don't like the extra dependency just for this...
		# TODO: Store this in db, so we don't have to calculate it every time
		tr = unidecode.unidecode(a['name'])
		if tr != a['name']:
			r[len(r) - 1]['name_tr'] = tr

	r.sort(key=lambda k: (k.get('name_tr') or k['name']).lower())
	return r


def get_searches():
	c = openDb().cursor()
	return c.execute('select * from searches').fetchall()


def getAlbum(id):
	c = openDb().cursor()

	album = c.execute('select * from albums where id=?', (id,)).fetchone()
	artist = c.execute('select * from artists where id=?', (album['artist'],)).fetchone()
	tracks = c.execute('select * from tracks where album=? order by discno, trackno', (album['id'],)).fetchall()

	album['coverdata'] = ''
	if album['cover']:
		t = album['cover'].split('.').pop()
		if t == 'jpg': t = 'jpeg'
		cover_cache = '{}/tmp/{}.{}'.format(_root, album['id'], t)

		def coverdata_str(d):
			nonlocal album, t
			album['coverdata'] = 'data:image/{};base64,{}'.format(
				t, base64.b64encode(d).decode())

		# Load from cache
		# TODO: Cache is never invalidated; we should do this in update.py
		if os.path.exists(cover_cache):
			coverdata_str(open(cover_cache, 'rb').read())
		# Convert to 800x800 if required, save result to cache
		elif Image is not None:
			img = Image.open(album['cover'])

			if img.size[0] > 800 or img.size[1] > 800:
				img.thumbnail((800, 800), Image.ANTIALIAS)
				out = io.BytesIO()
				img.save(out, img.format)
				cover = out.getvalue()
				open(cover_cache, 'wb').write(cover)
				coverdata_str(cover)
			else:
				coverdata_str(open(album['cover'], 'rb').read())
		# Load if smaller than 500KiB, else don't display
		else:
			if os.stat(album['cover']).st_size > 500 * 1024:
				album['coverdata'] = ''
			else:
				coverdata_str(open(album['cover'], 'rb').read())

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

	if k == 'dbpath': v = '{}/{}'.format(_root, v)
	config[k] = v


# The MIT License (MIT)
#
# Copyright © 2013-2015 Martin Tournoij
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
