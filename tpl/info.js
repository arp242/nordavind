(function() {
  var Info;

  window.Info = Info = (function() {

    Info.prototype._req = null;

    /*
    */

    function Info() {
      $('#info .table-wrapper').scrollbar({
        wheelSpeed: 150
      });
      $('#info').on('click', 'img', function(e) {
        var img;
        img = $(this);
        if (img.attr('src') === '') return;
        $('body').append("<div id='large-cover'>\n	<img src='" + (img.attr('src')) + "' alt=''>\n</div>");
        $('#large-cover').css({
          width: "" + (img.width()) + "px",
          height: "" + (img.height()) + "px"
        }).animate({
          width: '100%',
          height: '100%'
        }, {
          duration: 500
        });
        return $('#large-cover').one('click', function(e) {
          var _this = this;
          return $(this).animate({
            width: "" + (img.width()) + "px",
            height: "" + (img.height()) + "px"
          }, {
            complete: function() {
              return $(_this).remove();
            },
            duration: 500
          });
        });
      });
    }

    /*
    */

    Info.prototype.getInfo = function(trackId) {
      var album, artist, track;
      track = _cache.tracks[trackId];
      if (track == null) return [null, null, null];
      album = _cache.albums[track.album];
      artist = _cache.artists[album.artist];
      return [track, album, artist];
    };

    /*
    */

    Info.prototype.clear = function() {
      $('#info img').attr('src', '');
      return $('#info tbody').html('');
    };

    /*
    	Set info to trackId
    */

    Info.prototype.setTrack = function(trackId) {
      var my,
        _this = this;
      if (window._cache['tracks'][trackId] != null) {
        this._set(window._cache['tracks'][trackId]);
        return;
      }
      my = this;
      if (this._req) this._req.abort();
      return this._req = jQuery.ajax({
        url: "" + _root + "/get-album-by-track/" + trackId,
        type: 'get',
        dataType: 'json',
        success: function(data) {
          var t, _i, _len, _ref, _results;
          _this._req = null;
          window._cache['artists'][data.artist.id] = data.artist;
          window._cache['albums'][data.album.id] = data.album;
          _ref = data.tracks;
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            t = _ref[_i];
            window._cache['tracks'][t.id] = t;
            if (t.id === trackId.toNum()) {
              _results.push(my._set(t));
            } else {
              _results.push(void 0);
            }
          }
          return _results;
        }
      });
    };

    /*
    */

    Info.prototype._set = function(track) {
      var album, artist;
      album = window._cache['albums'][track.album];
      artist = window._cache['artists'][album.artist];
      $('#info img').one('load', function() {
        return $('#info .table-wrapper').width($('#info').width() - $('#info img').width() - 20);
      });
      $('#info img').attr('src', album.coverdata);
      return $('#info tbody').html('').append("<tr>\n	<th>Artist name</th>\n	<td>" + (artist.name.quote() || '[Unknown]') + "</td>\n</tr>\n<tr>\n	<th>Album title</th>\n	<td>" + (album.name.quote() || '[Unknown]') + "</td>\n</tr>\n<tr>\n	<th>Track title</th>\n	<td>" + (track.name.quote() || '[Unknown]') + "</td>\n</tr>\n<tr>\n	<th>Released</th>\n	<td>" + (track.released || '[Unknown]') + "</td>\n</tr>\n<tr>\n	<th>Track number</th>\n	<td>" + (track.trackno || '[Unknown]') + "</td>\n</tr>\n<tr>\n	<th>Total tracks</th>\n	<td>" + (album.numtracks || '[Unknown]') + "</td>\n</tr>\n<tr>\n	<th>Disc number</th>\n	<td>" + (track.discno || '[Unknown]') + "</td>\n</tr>\n<tr>\n	<th>Total discs</th>\n	<td>" + (album.numdiscs || '[Unknown]') + "</td>\n</tr>\n<tr>\n	<th>Length</th>\n	<td>" + (displaytime(track.length || '[Unknown]')) + "</td>\n</tr>\n<tr>\n	<th>Filename</th>\n	<td>" + (track.path.split('/').pop().quote()) + "</td>\n</tr>\n<tr>\n	<th>Directory</th>\n	<td>" + (track.path.split('/').slice(0, -1).join('/').quote()) + "</td>\n</tr>");
    };

    return Info;

  })();

}).call(this);
