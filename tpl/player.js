(function() {
  var Player;

  window.Player = Player = (function() {

    Player.prototype.codec = null;

    Player.prototype.audio = $('audio')[0];

    Player.prototype._nextAudio = null;

    Player.prototype._curplaying = {
      trackId: null,
      length: 1,
      start: 0
    };

    Player.prototype._bufstart = null;

    Player.prototype._draggingseekbar = false;

    /*
    */

    function Player() {
      this.initVolume();
      this.initSeekbar();
      this.initMouse();
      this.initPlayer();
    }

    /*
    */

    Player.prototype.initMouse = function() {
      var my;
      my = this;
      $('#player').on('click', '.settings', window.showSettings);
      $('#player').on('click', '.play', function(e) {
        var active;
        if (isNaN(my.audio.duration)) {
          active = $('#playlist .active');
          if (active.length > 0) return window.playlist.playRow(active);
          return window.playlist.playRow($('#playlist tbody tr:eq(0)'));
        }
        return my.audio.play();
      });
      $('#player').on('click', '.pause', function(e) {
        return my.audio.pause();
      });
      $('#player').on('click', '.forward', function(e) {
        return my.playNext();
      });
      $('#player').on('click', '.backward', function(e) {
        return my.playPrev();
      });
      return $('#player').on('click', '.stop', function(e) {
        return my.stop();
      });
    };

    /*
    */

    Player.prototype.initVolume = function() {
      var my;
      my = this;
      window.vol = new Slider({
        target: $('#player .volume'),
        move: function(pos) {
          my.setVol(pos);
          return Math.round(pos);
        }
      });
      if (store.get('volume') !== null) {
        return my.setVol(store.get('volume'));
      } else {
        return my.setVol(50);
      }
    };

    /*
    */

    Player.prototype.initSeekbar = function() {
      var my;
      my = this;
      return this.seekbar = new window.Slider({
        target: $('#player .seekbar'),
        start: function() {
          return my._draggingseekbar = true;
        },
        move: function(pos) {
          var v;
          v = my._curplaying.length / 100 * pos;
          my.audio.currentTime = v;
          return displaytime(v);
        },
        stop: function() {
          return my._draggingseekbar = false;
        }
      });
    };

    /*
    */

    Player.prototype.initPlayer = function(audio) {
      var my;
      if (audio == null) audio = null;
      if (!audio) audio = this.audio;
      my = this;
      $(audio).bind('play', function() {
        if (!$(this).hasClass('active')) return;
        $('#player').attr('class', 'right-of-library playing');
        return $('#playlist .playing .icon-pause').attr('class', 'icon-play');
      });
      $(audio).bind('pause', function() {
        if (!$(this).hasClass('active')) return;
        $('#player').attr('class', 'right-of-library paused');
        $('#playlist .playing .icon-play').attr('class', 'icon-pause');
        return $('#status span:eq(0)').html('Paused');
      });
      $(audio).bind('ended', function() {
        var album, artist, track, _ref;
        if (!$(this).hasClass('active')) return;
        $('.seekbar .buffer').css('width', '0px');
        my._bufstart = null;
        if (my._curplaying.length > 30) {
          _ref = window.info.getInfo(my._curplaying.trackId), track = _ref[0], album = _ref[1], artist = _ref[2];
          if (track) {
            window.scrobble.scrobble({
              timestamp: my._curplaying.start,
              artist: artist.name,
              album: album.name,
              track: track.name,
              trackNumber: track.trackno,
              duration: track.length
            });
          }
        }
        if (!my.playNext()) return my.stop();
      });
      $(audio).bind('timeupdate', function(e) {
        var next, t, v;
        if (!$(this).hasClass('active')) return;
        if (my._draggingseekbar) return;
        v = Math.min(100, my.audio.currentTime / my._curplaying.length * 100);
        my.seekbar.setpos(v);
        t = displaytime(my.audio.currentTime);
        $('#status span:eq(0)').html('Playing');
        $('#status span:eq(1)').html("" + t + " / " + (displaytime(my._curplaying.length)));
        if (my._nextAudio === null && my._curplaying.length - my.audio.currentTime < 10) {
          next = $('#playlist .playing').next();
          if ((next != null) && (next.attr('data-id') != null)) {
            my._nextAudio = {
              audio: document.createElement('audio'),
              id: next.attr('data-id')
            };
            my._nextAudio.audio.preload = 'auto';
            my._nextAudio.audio.src = "" + _root + "/play-track/" + (store.get('client')) + "/" + my.codec + "/" + (next.attr('data-id'));
            $(my.audio).after(my._nextAudio.audio);
            return my.initPlayer(my._nextAudio.audio);
          }
        }
      });
      return $(audio).bind('progress', function(e) {
        var c, dur, r;
        if (!$(this).hasClass('active')) return;
        try {
          c = Math.min(100, Math.round(my.audio.buffered.end(0) / my._curplaying.length * 100));
        } catch (exc) {
          return;
        }
        if (c === 100) {
          $('#status span:eq(2)').html("Buffer " + c + "%");
          return $('.seekbar .buffer').css('width', "" + c + "%");
        } else {
          if (!my.bufstart) {
            my.bufstart = new Date().getTime() / 1000;
            return;
          }
          dur = new Date().getTime() / 1000 - my.bufstart;
          r = (dur / c) * (100 - c);
          $('#status span:eq(2)').html("Buffer " + c + "% (~" + (displaytime(Math.round(r))) + "s remaining)");
          return $('.seekbar .buffer').css('width', "" + c + "%");
        }
      });
    };

    /*
    	Play audio file `trackId` of `length` seconds
    */

    Player.prototype.play = function(trackId, length) {
      var album, artist, row, track, _ref;
      if (this.codec === null) {
        return alert("Your browser doesn't seem to support either Ogg/Vorbis or MP3 playback");
      }
      this.bufstart = null;
      if ((this._nextAudio != null) && trackId !== this._nextAudio.id) {
        $(this._nextAudio.audio).remove();
        this._nextAudio = null;
      } else if (this._nextAudio != null) {
        this.audio.remove();
        this.audio = this._nextAudio.audio;
        this._nextAudio = null;
        this.audio.className = 'active';
      } else {
        this.audio.pause();
        this.audio.src = '';
        this.audio.src = "" + _root + "/play-track/" + (store.get('client')) + "/" + this.codec + "/" + trackId;
      }
      this._curplaying = {
        trackId: trackId,
        length: length,
        start: (new Date().getTime() / 1000).toNum() + new Date().getTimezoneOffset()
      };
      this.setVol();
      this.audio.play();
      $(this.audio).trigger('progress');
      row = $("#playlist tr[data-id=" + trackId + "]");
      $('#playlist tr').removeClass('playing');
      row.addClass('playing').find('td:eq(0)').html('<i class="icon-play"></i>');
      store.set('lasttrack', trackId);
      _ref = window.info.getInfo(trackId), track = _ref[0], album = _ref[1], artist = _ref[2];
      if (track) {
        return window.scrobble.nowPlaying({
          artist: artist.name,
          album: album.name,
          track: track.name,
          trackNumber: track.trackno,
          duration: track.length
        });
      }
    };

    /*
    	Try and play the next track
    */

    Player.prototype.playNext = function(prev) {
      var n;
      if (prev == null) prev = false;
      n = prev ? $('#playlist .playing').prev() : $('#playlist .playing').next();
      $('#playlist .playing').removeClass('playing');
      if (n.length > 0) {
        window.playlist.playRow(n);
        return true;
      } else {
        return false;
      }
    };

    /*
    	Try and play the previous track
    */

    Player.prototype.playPrev = function() {
      return this.playNext(true);
    };

    /*
    	Stop playing
    */

    Player.prototype.stop = function() {
      $('.seekbar .buffer').css('width', '0px');
      this.audio.pause();
      $('#playlist tr').removeClass('playing');
      this.audio.src = '';
      $('#player').attr('class', 'right-of-library stopped');
      store.set('lasttrack', null);
      this._bufstart = null;
      (function() {
        $('#status span').html('');
        return $('#status span:eq(0)').html('Stopped');
      }).timeout(150);
      if (this._nextAudio != null) {
        $(this._nextAudio.audio).remove();
        return this._nextAudio = null;
      }
    };

    /*
    	Set volume in percentage (0-100) & adjust for replaygain
    	If the volume is null, we'll set it to the current volume, but re-apply
    	replaygain (do this when switching tracks)
    */

    Player.prototype.setVol = function(v) {
      var apply, rg, scale, _ref, _ref2, _ref3;
      if (v == null) v = null;
      if (v === null) v = store.get('volume');
      store.set('volume', v);
      scale = 1;
      if (this._curplaying.trackId) {
        rg = false;
        apply = store.get('replaygain');
        if (apply === 'album') {
          rg = (_ref = window._cache.albums[(_ref2 = window._cache.tracks[this._curplaying.trackId]) != null ? _ref2.album : void 0]) != null ? _ref.rg_gain : void 0;
        } else if (apply === 'track') {
          rg = (_ref3 = window._cache.tracks[this._curplaying.trackId]) != null ? _ref3.rg_gain : void 0;
        }
        if (rg) scale = Math.pow(10, rg / 20);
      }
      this.audio.volume = v * scale / 100;
      return window.vol.setpos(store.get('volume'));
    };

    return Player;

  })();

}).call(this);
