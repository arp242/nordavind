// Generated by CoffeeScript 1.7.1
(function() {
  var Slider;

  window.debug = true;

  window.log = function() {
    if ((typeof console !== "undefined" && console !== null ? console.log : void 0) != null) {
      return console.log.apply(console, arguments);
    }
  };

  window.dbg = function() {
    if (window.debug && ((typeof console !== "undefined" && console !== null ? console.log : void 0) != null)) {
      return log.apply(this, arguments);
    }
  };

  window.$$ = function(s) {
    return $(s).toArray();
  };

  String.prototype.toNum = function() {
    return parseInt(this, 10);
  };

  Number.prototype.toNum = function() {
    return parseInt(this, 10);
  };

  jQuery.fn.replaceHTML = function(s, r) {
    return this.html(this.html().replace(s, r));
  };

  Function.prototype.timeout = function(time, args) {
    return this.timeoutId = setTimeout((function(_this) {
      return function() {
        return _this.apply(_this, args);
      };
    })(this), time);
  };

  Function.prototype.clearTimeout = function() {
    return clearTimeout(this.timeoutId);
  };

  Function.prototype.interval = function(time, args) {
    return this.intervalId = setInterval((function(_this) {
      return function() {
        return _this.apply(_this, args);
      };
    })(this), time);
  };

  Function.prototype.clearInterval = function() {
    return clearInterval(this.intervalId);
  };

  String.prototype.quote = function() {
    return this.replace(/</g, '&lt').replace(/>/g, '&gt').replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&apos;').replace(/\//g, '&#x2f;');
  };

  String.prototype.translit = function(str) {};

  jQuery.fn.findNext = function(sel, num, _prev) {
    var arewe, ref;
    if (num == null) {
      num = 1;
    }
    if (_prev == null) {
      _prev = false;
    }
    ref = _prev ? this.prev() : this.next();
    while (true) {
      if (ref.length === 0) {
        return false;
      }
      arewe = ref.is(sel);
      if (arewe) {
        num -= 1;
      }
      if (arewe && num === 0) {
        return ref;
      }
      ref = _prev ? ref.prev() : ref.next();
    }
  };

  jQuery.fn.findPrev = function(sel, num) {
    if (num == null) {
      num = 1;
    }
    return this.findNext(sel, num, true);
  };

  window.store = {
    get: function(k) {
      try {
        return JSON.parse(localStorage.getItem("nordavind_" + k));
      } catch (_error) {
        return null;
      }
    },
    set: function(k, v) {
      return localStorage.setItem("nordavind_" + k, JSON.stringify(v));
    },
    del: function(k) {
      return localStorage.removeItem("nordavind_" + k);
    },
    init: function(k, v) {
      if (!localStorage.getItem("nordavind_" + k)) {
        return localStorage.setItem("nordavind_" + k, JSON.stringify(v));
      }
    }
  };

  window.displaytime = function(sec) {
    var m, s;
    m = Math.floor(sec / 60);
    s = Math.floor(sec % 60);
    return "" + m + ":" + (s < 10 ? 0 : '') + s;
  };

  window.removeDialog = function() {
    $('#dialog').animate({
      top: '-200px',
      opacity: 0
    }, {
      duration: 200,
      done: function() {
        return $('#dialog').remove();
      }
    });
    return $('#backdrop').animate({
      opacity: 0
    }, {
      duration: 200,
      done: function() {
        return $('#backdrop').remove();
      }
    });
  };

  window.showDialog = function(content) {
    $('body').append("<div id=\"backdrop\"></div>\n<div id='dialog'>\n	<div class=\"content\">" + content + "</div>\n	<div class=\"buttons\"><button class=\"btn close\">Close</div></div>\n</div>");
    $(window).on('keydown.dialog', function(e) {
      if (e.keyCode !== 27) {
        return;
      }
      $(window).off('keydown.dialog');
      return window.settings.close();
    });
    $('#dialog').animate({
      top: '100px',
      opacity: 1
    }, {
      duration: 200
    });
    $('#backdrop').animate({
      opacity: 0.5
    }, {
      duration: 200
    });
    return $('#dialog .close').on('click', function(e) {
      e.preventDefault();
      return window.settings.close();
    });
  };

  window.babyUrADrag = function(handle, start, move, end) {
    var dragging, mousedown, mousemove, mouseup, origzindex;
    dragging = false;
    mousemove = function(e) {
      if (!dragging) {
        return;
      }
      setSize();
      return move != null ? move.apply(this, [e]) : void 0;
    };
    origzindex = $(handle).css('z-index');
    mousedown = function(e) {
      handle.addClass('dragging');
      dragging = true;
      $(handle).css('z-index', '99');
      document.body.focus();
      e.preventDefault();
      return start != null ? start.apply(this, [e]) : void 0;
    };
    mouseup = function(e) {
      handle.removeClass('dragging');
      dragging = false;
      $(handle).css('z-index', origzindex);
      return end != null ? end.apply(this, [e]) : void 0;
    };
    handle.on('mousedown', mousedown);
    $('body').on('mousemove', mousemove);
    return $('body').on('mouseup', mouseup);
  };

  window.Slider = Slider = (function() {
    function Slider(opt) {
      var h, my, setpos, start, stop, tooltip;
      this.opt = opt;
      my = this;
      opt.target = $(opt.target);
      opt.target.addClass('slider');
      h = opt.target.html();
      opt.target.html('');
      opt.target.append("<span class='slider-bar'>" + h + "</span>");
      opt.target.append('<span class="slider-handle"></span>');
      this.bar = opt.target.find('.slider-bar');
      this.handle = opt.target.find('.slider-handle');
      tooltip = null;
      setpos = function(e) {
        var left, max, tip;
        left = e.pageX - my.bar.offset().left - my.handle.width();
        max = my.bar.width() - my.handle.width();
        if (left < 0) {
          left = 0;
        }
        if (left > max) {
          left = max;
        }
        my.handle.css('left', "" + left + "px");
        if (my.opt.move) {
          tip = my.opt.move(my.getpos());
        }
        if (tip != null) {
          if (tooltip === null) {
            $(my.opt.target).append("<span id='tooltip'></span>");
            tooltip = $('#tooltip');
          }
          tooltip.html(tip);
          return tooltip.css('left', "" + (left - 20) + "px");
        }
      };
      stop = function() {
        if (my.opt.stop) {
          my.opt.stop();
        }
        $('#tooltip').remove();
        return tooltip = null;
      };
      start = function() {
        if (my.opt.start) {
          return my.opt.start();
        }
      };
      this.bar.bind('click', function(e) {
        start();
        setpos(e);
        return stop();
      });
      babyUrADrag(this.handle, start, setpos, stop);
    }

    Slider.prototype.getpos = function() {
      return this.handle.css('left').toNum() / ((this.bar.width() - this.handle.width()) / 100);
    };

    Slider.prototype.setpos = function(p) {
      return this.handle.css('left', "" + ((this.bar.width() - this.handle.width()) / 100 * p) + "px");
    };

    return Slider;

  })();

}).call(this);