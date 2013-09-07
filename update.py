#!/usr/bin/env python3
#
# Do a full update of the database
#

import sys, os

import nordavind

nordavind._root = os.path.dirname(os.path.realpath(sys.argv[0]))
nordavind.start()

walkdir = nordavind.config['musicpath']
if len(sys.argv) > 1:
	walkdir = sys.argv[1]
	if not walkdir.startswith('/'):
		walkdir = '%s/%s' % (nordavind.config['musicpath'], walkdir)

	if not os.path.exists(walkdir):
		print("Directory `%s' doesn't exist", walkdir)
		sys.exit(1)

for root, dirs, files in os.walk(walkdir):
	for f in files:
		try:
			if f.split('.').pop().lower() in ['mp3', 'flac']:
				nordavind.addOrUpdateTrack(('%s/%s' % (root, f)))
		except:
			print('Error with %s/%s' % (root, f))
			raise

c = nordavind._db.cursor()
for track in c.execute('select * from tracks').fetchall():
	if not os.path.exists(track['path']):
		c.execute('delete from tracks where id=?', (track['id'],))
nordavind._db.commit()
