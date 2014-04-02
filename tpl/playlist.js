(function() {
  var Playlist, selectBox,
    __indexOf = Array.prototype.indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  window.Playlist = Playlist = (function() {
    /*
    */
    function Playlist() {
      store.get('playlist').forEach(function(r) {
        return $('#playlist tbody').append(r);
      });
      $('#playlist-wrapper').scrollbar({
        wheelSpeed: 150
      });
      this.initMouse();
      this.initKeyboard();
      this.initSort();
      selectBox($('#playlist-wrapper'));
    }

    /*
    	Set a row as active
    */

    Playlist.prototype.setRowActive = function(row) {
      var rowheight;
      row = $(row).closest('tr');
      $('#playlist tr').removeClass('active');
      row.addClass('active');
      window.info.setTrack(row.attr('data-id'));
      rowheight = $('#playlist tbody tr:first').outerHeight();
      if (row.position().top > $('#playlist-wrapper').height() - rowheight) {
        $('#playlist-wrapper')[0].scrollTop += row.position().top - rowheight * 2;
        return $('#playlist-wrapper').scrollbar('update');
      } else if (row.position().top < rowheight) {
        return $('#playlist-wrapper')[0].scrollTop -= Math.floor($('#playlist-wrapper').height() / rowheight) * rowheight;
      }
    };

    /*
    	Select a row in the playlist
    */

    Playlist.prototype.selectRow = function(row, active) {
      if (active == null) active = true;
      if (!row) return false;
      row = $(row).closest('tr');
      row.addClass('selected');
      if (active) return this.setRowActive(row);
    };

    /*
    	Deselect a row ion the playlist
    */

    Playlist.prototype.deSelectRow = function(row, active) {
      if (active == null) active = true;
      row = $(row).closest('tr');
      row.removeClass('selected');
      if (active) return this.setRowActive(row);
    };

    /*
    	Select all rows from .active until `stop'
    */

    Playlist.prototype.selectRowsUntil = function(stop, active) {
      var dir, row, _results;
      if (active == null) active = true;
      if (!stop) return false;
      stop = $(stop).closest('tr');
      row = $('#playlist .active');
      if (row.length === 0) {
        this.selectRow(stop, active);
        return;
      }
      dir = stop.index() > row.index() ? 'next' : 'prev';
      _results = [];
      while (true) {
        this.selectRow(row, false);
        if (row.is(stop)) {
          if (active) this.setRowActive(row);
          break;
        }
        _results.push(row = dir === 'next' ? row.next() : row.prev());
      }
      return _results;
    };

    /*
    	Clear all selection
    */

    Playlist.prototype.clearSelection = function(active) {
      if (active == null) active = false;
      $('#playlist tr').removeClass('selected');
      if (active) return $('#playlist .active').removeClass('active');
    };

    /*
    	Play this table row
    */

    Playlist.prototype.playRow = function(r) {
      window.player.play($(r).attr('data-id'), $(r).attr('data-length'));
      this.clearSelection(true);
      return this.selectRow(r);
    };

    /*
    	Mouse binds
    */

    Playlist.prototype.initMouse = function() {
      var my;
      my = this;
      $('body').on('click', function(e) {
        var _ref;
        if (!((_ref = window._activepane) != null ? _ref.is('#playlist-wrapper') : void 0)) {
          return;
        }
        if ($(e.target).closest('tr').length === 1) return;
        return my.clearSelection();
      });
      $('#playlist tbody').on('click', 'tr', function(e) {
        if (e.shiftKey) {
          return my.selectRowsUntil(this);
        } else if (e.ctrlKey) {
          return my.selectRow(this);
        } else {
          my.clearSelection();
          return my.selectRow(this);
        }
      });
      return $('#playlist tbody').on('dblclick', 'tr', function(e) {
        my.clearSelection();
        my.selectRow(this);
        return my.playRow(this);
      });
    };

    /*
    */

    Playlist.prototype.initKeyboard = function() {
      var my;
      my = this;
      return $('body').bind('keydown', function(e) {
        var albums, n, r;
        if (!(typeof _activepane !== "undefined" && _activepane !== null ? _activepane.is('#playlist-wrapper') : void 0)) {
          return;
        }
        if (e.ctrlKey && e.keyCode === 65) {
          e.preventDefault();
          return $('#playlist tbody tr').addClass('selected');
        } else if (e.keyCode === 46) {
          e.preventDefault();
          albums = [];
          $('#playlist .selected').remove();
          window.info.clear();
          my.savePlaylist();
          my.cleanCache();
          if ($('#playlist tr:last').position().top < 15) {
            $('#playlist-wrapper')[0].scrollTop = 0;
            return $('#playlist-wrapper').scrollbar('update');
          }
        } else if (e.keyCode === 38) {
          e.preventDefault();
          r = $('#playlist .active');
          if (r.length === 0) return my.selectRow($('#playlist tbody tr:last'));
          if (r.prev().length === 0) return;
          if (e.shiftKey) {
            if (r.hasClass('selected') && r.prev().hasClass('selected')) {
              my.deSelectRow(r);
            }
            return my.selectRow(r.prev());
          } else if (e.ctrlKey) {
            return r.removeClass('active').prev().addClass('active');
          } else {
            my.clearSelection();
            return my.selectRow(r.prev());
          }
        } else if (e.keyCode === 40) {
          e.preventDefault();
          r = $('#playlist .active');
          if (r.length === 0) return my.selectRow($('#playlist tbody tr:first'));
          if (r.next().length === 0) return;
          if (e.shiftKey) {
            if (r.hasClass('selected') && r.next().hasClass('selected')) {
              my.deSelectRow(r);
            }
            return my.selectRow(r.next());
          } else if (e.ctrlKey) {
            return r.removeClass('active').next().addClass('active');
          } else {
            my.clearSelection();
            return my.selectRow(r.next());
          }
        } else if (e.keyCode === 34) {
          e.preventDefault();
          n = Math.floor($('#playlist-wrapper').height() / $('#playlist tr:last').outerHeight());
          if (e.shiftKey) {
            r = my.selectRowsUntil($('#playlist .active').findNext('tr', n));
            if (r === false) {
              return my.selectRowsUntil($('#playlist tbody tr:last'));
            }
          } else {
            my.clearSelection();
            r = my.selectRow($('#playlist .active').findNext('tr', n));
            if (r === false) return my.selectRow($('#playlist tbody tr:last'));
          }
        } else if (e.keyCode === 33) {
          e.preventDefault();
          n = Math.floor($('#playlist-wrapper').height() / $('#playlist tr:last').outerHeight());
          if (e.shiftKey) {
            r = my.selectRowsUntil($('#playlist .active').findPrev('tr', n));
            if (r === false) {
              return my.selectRowsUntil($('#playlist tbody tr:first'));
            }
          } else {
            my.clearSelection();
            r = my.selectRow($('#playlist .active').findPrev('tr', n));
            if (r === false) return my.selectRow($('#playlist tbody tr:first'));
          }
        } else if (e.keyCode === 36) {
          e.preventDefault();
          if (e.shiftKey) {
            return my.selectRowsUntil($('#playlist tbody tr:first'));
          } else if (e.ctrlKey) {
            $('#playlist .active').removeClass('active');
            return $('#playlist tbody tr:first').addClass('active');
          } else {
            my.clearSelection();
            return my.selectRow($('#playlist tbody tr:first'));
          }
        } else if (e.keyCode === 35) {
          e.preventDefault();
          if (e.shiftKey) {
            return my.selectRowsUntil($('#playlist tbody tr:last'));
          } else if (e.ctrlKey) {
            $('#playlist .active').removeClass('active');
            return $('#playlist tbody tr:last').addClass('active');
          } else {
            my.clearSelection();
            return my.selectRow($('#playlist tbody tr:last'));
          }
        } else if (e.keyCode === 13) {
          e.preventDefault();
          return $('#playlist .active').dblclick();
        }
      });
    };

    /*
    	Sorting
    */

    Playlist.prototype.initSort = function() {
      var my, sort;
      my = this;
      sort = null;
      return $('#playlist-thead').on('click', '.cell', function(e) {
        var body, dir, h, int, n, pn, psort, rows, sortFun;
        h = $(this);
        psort = null;
        if ($('#playlist-thead').find('.icon-sort-up').length > 0) {
          psort = $('#playlist-thead').find('.icon-sort-up').parent();
        } else if ($('#playlist-thead').find('.icon-sort-down').length > 0) {
          psort = $('#playlist-thead').find('.icon-sort-down').parent();
        }
        if (psort && h[0] === psort[0]) psort = null;
        dir = null;
        if (h.find('.icon-sort-up').length > 0) {
          dir = 'down';
          h.find('i').attr('class', 'icon-sort-down');
        } else if (h.find('.icon-sort-down').length > 0) {
          dir = 'up';
          h.find('i').attr('class', 'icon-sort-up');
        } else {
          dir = 'up';
          h.find('i').attr('class', 'icon-sort-up');
        }
        if (psort != null) psort.find('i').attr('class', '');
        body = $('#playlist tbody');
        rows = body.find('tr').toArray();
        n = h.index();
        pn = psort != null ? psort.index() : void 0;
        int = function(num) {
          return parseFloat(num.replace(':', '.'));
        };
        sortFun = function(rowa, rowb) {
          var a, b, fun, inpsort, r, _ref;
          if (((_ref = rowa.tagName) != null ? _ref.toLowerCase() : void 0) === 'tr') {
            a = $(rowa).find("td:eq(" + n + ")").text();
            b = $(rowb).find("td:eq(" + n + ")").text();
            inpsort = false;
          } else {
            inpsort = true;
            a = $(rowa).text();
            b = $(rowb).text();
          }
          if (dir === 'up' && h.attr('data-sort') === 'numeric') {
            fun = function() {
              if (int(a) === int(b)) return 0;
              if (int(a) > int(b)) {
                return 1;
              } else {
                return -1;
              }
            };
          } else if (dir === 'down' && h.attr('data-sort') === 'numeric') {
            fun = function() {
              if (int(a) === int(b)) return 0;
              if (int(b) > int(a)) {
                return 1;
              } else {
                return -1;
              }
            };
          } else if (dir === 'up') {
            fun = function() {
              return a.localeCompare(b);
            };
          } else if (dir === 'down') {
            fun = function() {
              return b.localeCompare(a);
            };
          }
          r = fun();
          if (r === 0 && !inpsort && (psort != null)) {
            r = sortFun($(rowa).find("td:eq(" + pn + ")"), $(rowb).find("td:eq(" + pn + ")"));
          }
          return r;
        };
        rows.sort(sortFun);
        body.html('');
        rows.forEach(function(r) {
          return body.append(r);
        });
        return my.savePlaylist();
      });
    };

    /*
    	Save the playlist to localStorage
    */

    Playlist.prototype.savePlaylist = function() {
      store.set('playlist', $$('#playlist tbody tr').map(function(r) {
        return r.outerHTML;
      }));
      $('#playlist-wrapper').scrollbar('update');
      return this.headSize();
    };

    /*
    	Get currently playing track
    */

    Playlist.prototype.getPlaying = function() {
      return $('#playlist .playing');
    };

    /*
    */

    Playlist.prototype.cleanCache = function() {
      var albums, artists, deleted, k, t, tracks, _ref, _ref2, _ref3, _ref4, _ref5, _ref6, _results;
      tracks = [];
      albums = [];
      artists = [];
      $$('#playlist tbody tr').forEach(function(row) {
        var albumid, artistid, trackid, _ref, _ref2;
        trackid = $(row).attr('data-id');
        albumid = (_ref = window._cache.tracks[trackid]) != null ? _ref.album : void 0;
        artistid = (_ref2 = window._cache.albums[albumid]) != null ? _ref2.artist : void 0;
        if (__indexOf.call(tracks, trackid) < 0) tracks.push(trackid);
        if (__indexOf.call(albums, albumid) < 0) albums.push(albumid);
        if (__indexOf.call(artists, artistid) < 0) return artists.push(artistid);
      });
      deleted = [];
      _ref = window._cache.tracks;
      for (k in _ref) {
        t = _ref[k];
        if (_ref2 = t.id, __indexOf.call(tracks, _ref2) < 0) {
          deleted.push(t.id);
          delete window._cache.tracks[k];
        }
      }
      _ref3 = window._cache.albums;
      for (k in _ref3) {
        t = _ref3[k];
        if (_ref4 = t.id, __indexOf.call(albums, _ref4) < 0) {
          delete window._cache.albums[k];
        }
      }
      _ref5 = window._cache.artists;
      _results = [];
      for (k in _ref5) {
        t = _ref5[k];
        if (_ref6 = t.id, __indexOf.call(artists, _ref6) < 0) {
          _results.push(delete window._cache.artists[k]);
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    /*
    */

    Playlist.prototype.headSize = function() {
      var w;
      $('#playlist thead th').each(function(i, cell) {
        return $("#playlist-thead .cell:eq(" + i + ")").css('width', "" + ($(cell).width() + 2) + "px");
      });
      w = $('#playlist-thead').width() - ($('#playlist-thead .cell:last').position().left + $('#playlist-thead .cell:last').outerWidth());
      return $('#playlist-thead > .cell:last').css('width', "+=" + w + "px");
    };

    return Playlist;

  })();

  /*
  */

  selectBox = function(target) {
    var box, dragging, maystart, prev, startX, startY, startrow;
    target = $(target);
    dragging = false;
    maystart = false;
    startrow = null;
    box = null;
    startX = 0;
    startY = 0;
    prev = '';
    target.on('mousedown.selectbox', function(e) {
      maystart = true;
      startX = e.pageX;
      return startY = e.pageY;
    });
    $('body').on('mouseup.selectbox', function(e) {
      maystart = false;
      dragging = false;
      startrow = null;
      if (box != null) box.remove();
      box = null;
      return prev = '';
    });
    return $('body').on('mousemove.selectbox', function(e) {
      var b, from, h, l, offs, r, row, t, to, w, _base, _base2, _i, _len, _ref, _ref2;
      if (!dragging && maystart && (Math.abs(startX - e.pageX) > 5 || Math.abs(startY - e.pageY) > 5)) {
        dragging = true;
        window._activepane = $('#playlist-wrapper');
        $('.pane-active').removeClass('pane-active');
        window._activepane.addClass('pane-active');
        $('body').append('<div id="selectbox"></div>');
        box = $('#selectbox');
        box.css({
          left: "" + startX + "px",
          top: "" + startY + "px"
        });
        if (typeof window.getSelection === "function") {
          if (typeof (_base = window.getSelection()).empty === "function") {
            _base.empty();
          }
        }
        if (typeof window.getSelection === "function") {
          if (typeof (_base2 = window.getSelection()).removeAllRanges === "function") {
            _base2.removeAllRanges();
          }
        }
        if ((_ref = document.selection) != null) _ref.empty();
        document.body.focus();
        e.preventDefault();
      }
      if (!dragging) return;
      row = $(e.target).closest('tr');
      if (row.length > 0) {
        if (startrow == null) startrow = row;
        if (row.index() > startrow.index()) {
          from = startrow.index();
          to = row.index() + 1;
        } else if (row.index() < (startrow != null ? startrow.index() : void 0)) {
          from = row.index();
          to = startrow.index() + 1;
        } else {
          from = row.index();
          to = row.index();
        }
        if (("" + from + "-" + to) !== ("" + prev.from + "-" + prev.to)) {
          if (from !== prev.from) {
            $("#playlist tr:lt(" + from + ")").removeClass('selected');
          }
          if (to !== prev.to) {
            $("#playlist tr:gt(" + to + ")").removeClass('selected');
          }
          _ref2 = $('#playlist tbody tr').slice(from, to);
          for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
            r = _ref2[_i];
            window.playlist.selectRow(r, false);
          }
          window.playlist.selectRow(row);
        }
        prev = {
          from: from,
          to: to
        };
      }
      w = $(window).width();
      h = $(window).height();
      if (e.pageX > startX) {
        l = startX;
        r = w - e.pageX;
      } else {
        l = e.pageX;
        r = w - startX;
      }
      if (e.pageY > startY) {
        t = startY;
        b = h - e.pageY;
      } else {
        t = e.pageY;
        b = h - startY;
      }
      offs = $('#playlist-wrapper').offset();
      l = Math.max(l, offs.left);
      return box.css({
        left: l + 'px',
        right: r + 'px',
        top: t + 'px',
        bottom: b + 'px'
      });
    });
  };

}).call(this);
