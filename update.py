#!/usr/bin/env python3
#
# Do a full update of the database
#

import argparse, os, sys, subprocess

import nordavind


nordavind._root = os.path.dirname(os.path.realpath(sys.argv[0]))

parser = argparse.ArgumentParser(description='Update the nordavind database')
parser.add_argument('-a', '--add-only', action='store_true',
	help="Only add new files (don't update existing or delete missing); this is faster")
parser.add_argument('-r', '--no-replaygain', action='store_true',
	help="Don't scan files for replaygain")
parser.add_argument('-v', '--verbose', action='store_true',
	help='Enable verbose messages')
parser.add_argument('-q', '--quiet', action='store_true',
	help='Quiet output; only show errors')
parser.add_argument('paths', nargs='*',
	help='Directories to (recursively) scan for files; defaults to musicpath')
args = vars(parser.parse_args())
if len(args['paths']) == 0: args['paths'] = [nordavind.config['musicpath']]

if args['verbose'] and args['quiet']:
	print('Using both -v/--verbose and -q/--quiet makes no sense. Choose one.',
		file=sys.stderr)
	sys.exit(1)

if args['verbose']: nordavind.update.verbose = True


def verbose(msg):
	if args['verbose']: print(msg)


paths = []
for path in args['paths']:
	if not path.startswith('/'):
		path = '{}/{}'.format(nordavind.config['musicpath'], path)

	if not os.path.exists(path):
		print("Error: Directory `{}' doesn't exist".format(path), file=sys.stderr)
		sys.exit(1)
	paths.append(path)
args['paths'] = paths


db = nordavind.openDb()
c = db.cursor()

existing_paths = []
if args['add_only']:
	existing_paths = [ r['path'] for r in c.execute('select path from tracks').fetchall() ]


for path in args['paths']:
	for root, dirs, files in os.walk(path):
		for f in files:
			full_path = '{}/{}'.format(root, f)
			try:
				if full_path in existing_paths: continue
				if f.split('.').pop().lower() in ['mp3', 'flac', 'ogg']:
					nordavind.update.add_or_update_track(full_path, not args['no_replaygain'])
			except:
				print("Error: `{}': {}".format(full_path, sys.exc_info()[1]))
				raise

# Delete old tracks
if not args['add_only']:
	for track in c.execute('select * from tracks').fetchall():
		if not os.path.exists(track['path']):
			c.execute('delete from tracks where id=?', (track['id'],))
		db.commit()
