#!/usr/bin/env python3
#
# Find and add new items to the library. Does *not* process updates or deletes
#

import sys, os

import nordavind

nordavind._root = os.path.dirname(os.path.realpath(sys.argv[0]))

db = nordavind.openDb()
c = db.cursor()
paths = [ r['path'] for r in c.execute('select path from tracks').fetchall() ]

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
					if '%s/%s' % (root, f) in paths: continue
					nordavind.update.add_or_update_track(('%s/%s' % (root, f)))
			except:
				print('Error with %s/%s' % (root, f))
				raise
