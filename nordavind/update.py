import datetime, glob, os, re, subprocess, sqlite3
import nordavind

from mutagen.flac import FLAC
from mutagen.easyid3 import EasyID3
from mutagen.mp3 import MP3
from mutagen.mp3 import EasyMP3
from mutagen.ogg import OggFileType


rg_commands = {
	'flac': ['metaflac', '--add-replay-gain'],
	'mp3': ['mp3gain', '-a', '-s', 'i'],
	'ogg': ['vorbisgain', '-asf'],
	'wv': ['wvgain', '-a'],
}


verbose = False
def dbg(msg, *args):
	if verbose: print(msg.format(*args))


def add_or_update_track(path, apply_replaygain=True):
	db = nordavind.openDb()
	c = db.cursor()
	path = re.sub('/+', '/', path)
	tags = get_tags(path)

	track = c.execute('select * from tracks where path = ?', (path,)).fetchone()

	# Existing track
	if track is not None:
		artist_id = _add_or_update_artist(c, tags.get('albumartist') or tags.get('artist'))
		album_id = _add_or_update_album(c, id=track['album'], tags=tags, path=path, artist=artist_id)

		dbg('Updating track {}; {}', track['id'], path)
		if apply_replaygain and int(track['discno']) == 1 and int(track['trackno']) == 1:
			if tags.get('replaygain_album_gain', None) == None:
				apply_rg(path)
				tags = get_tags(path)

		sql_update(c, table='tracks', id=track['id'], data={
			'name': tags.get('title'),
			'trackno': tags.get('tracknumber'),
			'discno': tags.get('discnumber', 1),
			'length': tags.get('length'),
			'rg_gain': rg_gain(tags, 'track'),
			'rg_peak': rg_peak(tags, 'track'),
		})
	# New track
	else:
		artist_id = _add_or_update_artist(c, tags.get('albumartist') or tags.get('artist'))
		album_id = _add_or_update_album(c, name='??', path=path, tags=tags, artist=artist_id)

		dbg('Inserting track {}', path)
		if apply_replaygain and int(track['discno']) == 1 and int(track['trackno']) == 1:
			apply_rg(path)
			tags = get_tags(path)

		sql_insert(c, 'tracks', {
			'path': path,
			'name': tags.get('title'),
			'album': album_id,
			'trackno': tags.get('tracknumber'),
			'discno': tags.get('discnumber', 1),
			'length': tags.get('length'),
			'rg_gain': rg_gain(tags, 'track'),
			'rg_peak': rg_peak(tags, 'track'),
		})

	db.commit()


def _add_or_update_artist(c, name=None, id=None):
	if name:
		artist = c.execute('select * from artists where name = ?', (name,)).fetchone()

	if name is not None and artist is not None:
		# We found it ... nothing to update right now
		return artist['id']
	elif id is not None:
		return id
	else:
		dbg('Inserting artist {}', name)
		c.execute('insert into artists (name) values (?)', (name,))
		return c.lastrowid


def _add_or_update_album(c, name=None, id=None, path=None, tags=None, artist=None):
	if artist is not None:
		album = c.execute('select * from albums where artist = ? and name = ?',
			(artist, tags.get('album'),)).fetchone()
	elif id is not None:
		album = c.execute('select * from albums where id = ?', (id,)).fetchone()
	else:
		album = None

	released = lambda: tags.get('date', '').split('-')[0]

	# Only update the album for the first track; this prevents this from being
	# executed for every track in the album
	if album is not None and int(tags.get('tracknumber', 0)) == 1:
		dbg('Updating album {}', album['id'])
		sql_update(c, table='albums', id=album['id'], data={
			'cover': find_cover(path),
			'released': released(),
			'rg_gain': rg_gain(tags, 'album'),
			'rg_peak': rg_peak(tags, 'album'),
		})
		return album['id']
	elif album is not None:
		return album['id']
	else:
		dbg('Inserting album {}', name)
		sql_insert(c, 'albums', {
			'artist': artist,
			'name': tags.get('album'),
			'released': released(),
			'cover': find_cover(path),
			'numtracks': tags.get('tracktotal'),
			'numdiscs': tags.get('disctotal', 1),
			'rg_gain': rg_gain(tags, 'album'),
			'rg_peak': rg_peak(tags, 'album'),
			'added_on': str(datetime.datetime.now())
		})
		return c.lastrowid


def get_tags(path):
	if path.endswith('.flac'):
		f = FLAC(path)
	elif path.endswith('.mp3'):
		f = EasyMP3(path)
	elif path.endswith('.ogg'):
		f = OggFileType(path)
	else:
		raise 'Unsupported file format: {}'.format(path)

	r = {}
	for k, v in f.tags.items():
		if k in ['discnumber', 'tracknumber']:
			v = [v[0].split('/')[0]]
		r[k.lower()] = v if len(v) > 1 else v[0]

	# EasyMP3 doesn't do TXXX
	if path.endswith('.mp3'):
		f = MP3(path)
		for t in f.tags.getall('TXXX'):
			r[t.desc.lower()] = t.text if len(t.text) > 1 else t.text[0]

	r['length'] = f.info.length
	return r


def find_cover(path):
	for p in ['cover.jpg', 'cover.jpeg', 'cover.png', 'front.jpg', 'front.jpeg', 'front.png']:
		cover = '{}/{}'.format(os.path.dirname(path), p)
		if os.path.exists(cover):
			return cover
		else:
			return None


def apply_rg(first_track):
	ext = first_track.split('.').pop()
	d = os.path.dirname(first_track)
	all_tracks = glob.glob('{}/*.{}'.format(d, ext))
	cmd = rg_commands[ext] + all_tracks
	dbg(str(cmd))
	subprocess.call(cmd)


def sql_update(cursor, table, id, data):
	query = 'update {} set {} where id={}'.format(
		table,
		', '.join([ '{}=?'.format(k) for k in data.keys() ]),
		id)

	cursor.execute(query, tuple(data.values()))


def sql_insert(cursor, table, data):
	query = 'insert into {} ({}) values ({})'.format(
		table, ', '.join(data.keys()), ('?, ' * len(data))[:-2] )

	cursor.execute(query, tuple(data.values()))


def rg_gain(tags, t):
	return float(tags.get('replaygain_{}_gain'.format(t), '0').replace('dB', ''))


def rg_peak(tags, t):
	return float(tags.get('replaygain_{}_peak'.format(t), 0))
