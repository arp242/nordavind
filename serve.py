#!/usr/bin/env python3
#
# http://code.arp242.net/nordavind
#
# Copyright © 2013 Martin Tournoij <martin@arp242.net>
# See below for full copyright
#

import sys, json, os, datetime

import cherrypy

import nordavind, nordavind.audio


def JSONDefault(obj):
	if obj.__class__.__name__ == 'datetime':
		return obj.strftime('%Y-%m-%d %H:%M')


def dbcache():
	mtime = datetime.datetime.fromtimestamp(int(os.stat(nordavind.config['dbpath']).st_mtime))
	fmt = '%a, %d %b %Y %H:%M:%S GMT'
	cherrypy.response.headers['Last-Modified'] = mtime.strftime(fmt)
	cherrypy.response.headers['Cache-Control'] = 'max-age=%s' % (86400 * 365,)
	cherrypy.response.headers['Expires'] = (mtime + datetime.timedelta(days=7)).strftime(fmt)


class AgentCooper:
	@cherrypy.expose
	def index():
		dbcache()
		return nordavind.template('main.html', {
			'version': '1.0-dev',
			'library': nordavind.getLibrary(),
		})


	@cherrypy.expose
	def get_settings():
		return nordavind.template('settings.html')


	@cherrypy.expose
	def lastfm_callback(token=None):
		return '''
			<html><head></head></html><body>
			<script>localStorage.setItem('nordavind_token', '%s'); window.close()</script>
			You can close this window
			</body></html>
		''' % (token,)


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

		cherrypy.response.headers['Content-Type'] = 'audio/%s' % codec
		return nordavind.playTrack(client, codec, trackid)
	play_track._cp_config = {'response.stream': True}


	@cherrypy.expose
	def tpl(*args, **kwargs):
		path = '%s/tpl/%s' % (nordavind._root, '/'.join(args))

		if not os.path.exists(path):
			raise cherrypy.NotFound()

		mtime = datetime.datetime.fromtimestamp(int(os.stat('config.cfg').st_mtime))
		fmt = '%a, %d %b %Y %H:%M:%S GMT'
		cherrypy.response.headers['Last-Modified'] = mtime.strftime(fmt)
		cherrypy.response.headers['Cache-Control'] = 'max-age=%s' % (86400 * 365,)
		cherrypy.response.headers['Expires'] = (mtime + datetime.timedelta(days=7)).strftime(fmt)

		return cherrypy.lib.static.serve_file(path)


server = '0.0.0.0'
port = 8001

if len(sys.argv) > 1:
	listen = sys.argv[1].split(':')
	server = listen[0]
	if len(listen) > 1:
		port = listen[1]

cherrypy.config.update({
	'server.socket_host': server,
	'server.socket_port': port,
})

cherrypy.quickstart(AgentCooper, config={
	'/': {
		'tools.gzip.on': True,
		'tools.gzip.mime_types': ['text/css', 'text/html', 'text/plain', 'application/json', 'application/javascript'],

		'tools.auth_digest.on': True,
		'tools.auth_digest.realm': 'Nordavind',
		'tools.auth_digest.key': nordavind.config['authkey'],
		'tools.auth_digest.get_ha1': cherrypy.lib.auth_digest.get_ha1_dict_plain(
			{ nordavind.config['user']: nordavind.config['password'] }
		)
	}
})


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
