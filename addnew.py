#!/usr/bin/env python3
#
# Find and add new items to the library. Does *not* process updates or deletes
#

import sys, os

import nordavind

nordavind._root = os.path.dirname(os.path.realpath(sys.argv[0]))

db = nordabind.openDb()
c = db.cursor()
paths = [ r['path'] for r in c.execute('select path from tracks').fetchall() ]

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
				if '%s/%s' % (root, f) in paths: continue
				nordavind.addOrUpdateTrack(('%s/%s' % (root, f)))
		except:
			print('Error with %s/%s' % (root, f))
			raise

