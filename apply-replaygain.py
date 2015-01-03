#!/usr/bin/env python3
#
# Apply replaingain to the entries in the db that don't have it already
#

import os, subprocess, sys

import nordavind

nordavind._root = os.path.dirname(os.path.realpath(sys.argv[0]))

commands = {
	'flac': ['metaflac', '--add-replay-gain'],
	'mp3': ['mp3gain', '-a', '-s', 'i'],
	'ogg': ['vorbisgain', '-asf'],
	'wv': ['wvgain', '-a'],
}


c = nordavind.openDb().cursor()

tracks = c.execute('''select tracks.album, tracks.path from albums
	join tracks on tracks.album = albums.id
	where albums.rg_gain is 0
	order by tracks.album''').fetchall()

albums = {}
for track in tracks:
	if albums.get(track['album']) is None:
		albums[track['album']] = []
	albums[track['album']].append(track['path'])

print('Updating %s albums (%s tracks)' % (len(albums), len(tracks)))

for i, album in enumerate(albums.values()):
	print('\rWorking on %s    ' % (i + 1), end='')

	ext = album[0].split('.').pop()
	cmd = commands[ext] + album
	subprocess.call(cmd)

	[ nordavind.update.add_or_update_track(f) for f in album ]
print()
