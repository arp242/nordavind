#!/usr/bin/env python3
#
# Do a full update of the database
#

import sys, os

import nordavind

nordavind._root = os.path.dirname(os.path.realpath(sys.argv[0]))

if len(sys.argv) == 1:
	walkdirs = [nordavind.config['musicpath']]
else:
	walkdirs = []
	for walkdir in sys.argv[1:]:
		if not walkdir.startswith('/'):
			walkdir = '%s/%s' % (nordavind.config['musicpath'], walkdir)

		if not os.path.exists(walkdir):
			print("Directory `%s' doesn't exist", walkdir)
			sys.exit(1)
		walkdirs.append(walkdir)

for walkdir in walkdirs:
	for root, dirs, files in os.walk(walkdir):
		for f in files:
			try:
				if f.split('.').pop().lower() in ['mp3', 'flac']:
					nordavind.update.add_or_update_track(('%s/%s' % (root, f)))
			except:
				print('Error with %s/%s' % (root, f))
				raise

# Delete old tracks
db = nordavind.openDb()
c = db.cursor()
for track in c.execute('select * from tracks').fetchall():
	if not os.path.exists(track['path']):
		c.execute('delete from tracks where id=?', (track['id'],))
db.commit()
