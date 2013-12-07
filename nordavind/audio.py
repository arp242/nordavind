""" Deal with audio data

This mostly uses commandline tools, not because it's the fastest or even te
`best' way, but because it's easy, requires little programming, and very few
dependencies.
Libraries such as gstreamer are great, but it pulls in half of Gnome as a
dependency, which is okay for a desktop, but not always okay for a server.
"""


import subprocess, sys


__all__ = ['convert']


def convert(path, codec):
	decode = getattr(sys.modules[__name__], 'decode_' + path.split('.').pop())
	encode = getattr(sys.modules[__name__], 'encode_' + codec)

	if encode == decode:
		fp = open(path, 'r')
	else:
		src = open(path, 'r')
		wav = decode(src)
		fp = encode(wav)

	while True:
		buf = fp.read(1024)
		if not buf: break
		yield buf


'''
def playTrack_clean(id):
	global _procs

	if _procs.get(id):
		cleanCache(id)
		_procs.get(id).kill()
		del _procs[id]
'''



'''
		t = path.split('.').pop()
		if codec == 'ogg':
			if t == 'flac':
				cmd = 'flac -sd %s -o - | oggenc - -q8 -Qo -' % shlex.quote(path)
			elif t == 'mp3':
				cmd = 'mpg123 -qw- %s | oggenc - -q8 -Qo -' % shlex.quote(path)
			elif t == 'ogg':
				cmd = 'cat %s' % shlex.quote(path)
				cache = None
		elif codec == 'mp3':
			if t == 'flac':
				cmd = 'flac -sd %s -o - | lame --quiet -V2 - -' % shlex.quote(path)
			elif t == 'ogg':
				cmd = 'oggdec -Qo- %s | lame --quiet -V2 - -' % shlex.quote(path)
			elif t == 'mp3':
				cmd = 'cat %s' % shlex.quote(path)
				cache = None

		_procs[id] = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE)

		if cache is not None:
			cachefp = open(cache + '_temp', 'wb')

		while True:
			buf = _procs[id].stdout.read(1024)
			if not buf: break
			if cache is not None: cachefp.write(buf)
			yield buf

		del _procs[id]
		if cache is not None:
			cachefp.close()
			os.rename(cache + '_temp', cache)
'''


def _exec(fp, cmd):
	proc = subprocess.Popen(cmd, stdin=fp, stdout=subprocess.PIPE)

	# TODO: Better error checking

	return proc.stdout


def decode_flac(fp): return _exec(fp, ['flac', '-s', '-d', '-o-', '-'])
def decode_ogg(fp): return _exec(fp, ['oggdec', '-Q', '-o-'])
def decode_mp3(fp): return _exec(fp, ['mpg123', '-q', '-w-', '-'])
def encode_ogg(fp): return _exec(fp, ['oggenc',  '-', '-q8', '-Q', '-o-'])
def encode_mp3(fp): return _exec(fp, ['lame', '--quiet', '-V2', '-', '-'])
