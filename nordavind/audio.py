""" Deal with audio data

This mostly uses commandline tools, not because it's the fastest or even te
`best' way, but because it's easy, requires little programming, and very few
dependencies.
Libraries such as gstreamer are great, but it pulls in half of Gnome as a
dependency, which is okay for a desktop, but not always okay for a server.
"""


import subprocess, sys


__all__ = ['convert', 'clean']
_procs = {}

def convert(client, id, path, codec):
	decode = getattr(sys.modules[__name__], 'decode_' + path.split('.').pop())
	encode = getattr(sys.modules[__name__], 'encode_' + codec)

	if encode == decode:
		fp = open(path, 'r')
	else:
		src = open(path, 'r')
		wav = decode(client, id, src)
		fp = encode(client, id, wav)

	while True:
		buf = fp.read(1024)
		if not buf: break
		yield buf


def clean(client, id):
	global _procs

	id = str(id)
	#print('==> client: {}'.format(client))
	#print('==> id: {} {}'.format(id), type(id))
	#print('==> _procs: {}'.format(_procs))
	#print('==> _proc.get(client): {}'.format(_procs.get(client)))
	#print('==> _procs.get(client).get(id): {}'.format(_procs.get(client).get(id)))
	#print('==> key_types: {}'.format(list(map(type,_procs.get(client).keys()))))
	if _procs.get(client) and _procs.get(client).get(id):
		_procs[client][id].reverse()
		for p in _procs[client][id]:
			print('killing {}; {}', p, _procs)
			p.kill()
		del _procs[client][id]


def _exec(client, id, fp, cmd):
	global _procs

	if _procs.get(client) is None: _procs[client] = {}
	if _procs[client].get(id) is None: _procs[client][id] = []

	proc = subprocess.Popen(cmd, stdin=fp, stdout=subprocess.PIPE)
	_procs[client][id].append(proc)

	# TODO: Better error checking
	return proc.stdout


def decode_flac(client, id, fp):
	return _exec(client, id, fp, ['flac', '-s', '-d', '-o-', '-'])

def decode_ogg(client, id, fp):
	return _exec(client, id, fp, ['oggdec', '-Q', '-o-'])

def decode_mp3(client, id, fp):
	return _exec(client, id, fp, ['mpg123', '-q', '-w-', '-'])

def encode_ogg(client, id, fp):
	return _exec(client, id, fp, ['oggenc',  '-', '-q8', '-Q', '-o-'])

def encode_mp3(client, id, fp):
	return _exec(client, id, fp, ['lame', '--quiet', '-V2', '-', '-'])
