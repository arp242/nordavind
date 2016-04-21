#!/usr/bin/env python3
#
# http://code.arp242.net/nordavind
#
# Copyright © 2013-2015 Martin Tournoij <martin@arp242.net>
# See below for full copyright
#

import sys, json, os, datetime

import cherrypy

import nordavind, nordavind.audio


def JSONDefault(obj):
	if obj.__class__.__name__ == 'datetime':
		return obj.strftime('%Y-%m-%d %H:%M')


def set_cache(path):
	mtime = datetime.datetime.fromtimestamp(int(os.stat(path).st_mtime))
	fmt = '%a, %d %b %Y %H:%M:%S GMT'

	cherrypy.response.headers['Last-Modified'] = mtime.strftime(fmt)
	cherrypy.response.headers['Cache-Control'] = 'max-age={}, must-revalidate'.format(86400 * 365)
	cherrypy.response.headers['Expires'] = (mtime + datetime.timedelta(days=7)).strftime(fmt)
def dbcache(): set_cache(nordavind.config['dbpath'])


class AgentCooper:
	@cherrypy.expose
	def index():
		dbcache()
		return nordavind.template('main.html', {
			'version': '1.0-dev',
			'library': nordavind.getLibrary(),
			'searches': nordavind.get_searches(),
		})


	@cherrypy.expose
	def get_settings():
		return nordavind.template('settings.html')


	@cherrypy.expose
	def lastfm_callback(token=None):
		return '''
			<html><head></head></html><body>
			<script>localStorage.setItem('nordavind_token', '{}'); window.close()</script>
			You can close this window
			</body></html>
		'''.format(token)


	@cherrypy.expose
	def get_album(albumid):
		dbcache()
		return json.dumps(nordavind.getAlbum(albumid), default=JSONDefault)


	@cherrypy.expose
	def get_album_by_track(trackid):
		dbcache()
		return json.dumps(nordavind.getAlbumByTrack(trackid), default=JSONDefault)


	@cherrypy.expose
	def play_track(client, codec, trackid):
		cherrypy.request.hooks.attach('on_end_request',
			lambda: nordavind.audio.clean(client, trackid), True)

		c = nordavind.openDb().cursor()
		track = c.execute('select * from tracks where id=?', (trackid,)).fetchone()

		cherrypy.response.headers['Content-Type'] = 'audio/{}'.format(codec)
		cherrypy.response.headers['X-Content-Duration'] = track['length']

		def play():
			for buf in nordavind.audio.convert(client, track['id'], track['path'], codec):
				yield buf
		return play()
	play_track._cp_config = {'response.stream': True}


	@cherrypy.expose
	def stream_path(path):
		path = os.path.realpath(path)
		if not path.startswith(nordavind.config['musicpath']):
			raise cherrypy.HTTPError(401)

		mime = {
			'flac': 'x-flac',
			'mp3': 'mpeg',
			'ogg': 'ogg',
		}.get(path.split('.').pop())
		size = os.stat(path).st_size

		cherrypy.response.headers['Content-Length'] = size
		cherrypy.response.headers['Content-Type'] = 'audio/{}'.format(mime)

		fp = open(path, 'rb')
		def go():
			while True:
				d = fp.read(4096)
				if d is None: break
				yield d
		return go()
	stream_path._cp_config = {'response.stream': True}


	@cherrypy.expose
	def sql_search(sql):
		db = nordavind.openDb(create=False, read_only=True)
		c = db.cursor()

		try:
			result = c.execute('select id from albums where {}'.format(sql.strip('$').strip()))
			result = {
				'success': True,
				'albums': [ r['id'] for r in result.fetchall() ],
			}
		except Exception as exc:
			result = {
				'success': False,
				'error': str(exc),
			}

		return json.dumps(result, default=JSONDefault)


	@cherrypy.expose
	def save_search(search, name=None, search_id=0):
		db = nordavind.openDb(create=False)
		c = db.cursor()
		if search_id > 0:
			c.execute('update searches set name=?, search=? where id=?',
				(name, search, namesearch_id,))
		else:
			c.execute('insert into searches (name, search) values (?, ?)',
				(search, search_id))
		db.commit()
		return json.dumps({'success': True}, default=JSONDefault)


	@cherrypy.expose
	def submit_rating(album_id, rating):
		db = nordavind.openDb(create=False)
		c = db.cursor()
		c.execute('update albums set rating=? where id=?', (rating, album_id,))
		db.commit()
		return json.dumps({'success': True}, default=JSONDefault)


	@cherrypy.expose
	def default(*args, **kwargs):
		path = '{}/public/{}'.format(nordavind._root, '/'.join(args))
		if not os.path.exists(path): raise cherrypy.NotFound()

		set_cache(path)

		if path.endswith('.woff'):
			cherrypy.response.headers['Content-Type'] = 'application/font-woff'

		return cherrypy.lib.static.serve_file(path)


def error_401(status, message, traceback, version):
	return 'Wrong username/password'


def error_404(status, message, traceback, version):
	return '404: Not found'


server = '0.0.0.0'
port = 8001

if len(sys.argv) > 1:
	listen = sys.argv[1].split(':')
	server = listen[0]
	if len(listen) > 1:
		port = int(listen[1])

cherrypy.config.update({
	'server.socket_host': server,
	'server.socket_port': port,
	'error_page.404': error_404,
	'error_page.401': error_401,
})

config = {
	'tools.gzip.on': True,
	'tools.gzip.mime_types': ['text/css', 'text/html', 'text/plain', 'application/json', 'application/javascript'],
}

if nordavind.config.get('user') and nordavind.config.get('password'):
	config.update({
		'tools.auth_digest.on': True,
		'tools.auth_digest.realm': 'Nordavind',
		'tools.auth_digest.key': nordavind.config['authkey'],
		'tools.auth_digest.get_ha1': cherrypy.lib.auth_digest.get_ha1_dict_plain({
			nordavind.config['user']: nordavind.config['password']
		})
	})

cherrypy.quickstart(AgentCooper, config={'/':  config})


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
