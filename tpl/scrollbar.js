/* Copyright (c) 2012 HyeonJe Jun (http://github.com/noraesae)
 * Licensed under the MIT License
 */
((function ($) {

  // The default settings for the plugin
  var defaultSettings = {
    wheelSpeed: 10,
    wheelPropagation: false,
    minScrollbarLength: null
  };

  $.fn.scrollbar = function (suppliedSettings, option) {
    return this.each(function () {
      // Use the default settings
      var settings = $.extend(true, {}, defaultSettings),
          $this = $(this);

      if (typeof suppliedSettings === "object") {
        // But over-ride any supplied
        $.extend(true, settings, suppliedSettings);
      }
	  else {
        // If no settings were supplied, then the first param must be the option
        option = suppliedSettings;
      }

      // Catch options

      if (option === 'update') {
        if ($this.data('perfect-scrollbar-update')) {
          $this.data('perfect-scrollbar-update')();
        }
        return $this;
      }
      else if (option === 'destroy') {
        if ($this.data('perfect-scrollbar-destroy')) {
          $this.data('perfect-scrollbar-destroy')();
        }
        return $this;
      }

      if ($this.data('perfect-scrollbar')) {
        // if there's already perfect-scrollbar
        return $this.data('perfect-scrollbar');
      }


	  /**
	   * generate new perfectScrollbar
	   */

      $this.addClass('ps-container');

      var $scrollbarY = $("<div class='ps-scrollbar-y'></div>").appendTo($this),
          containerWidth,
          containerHeight,
          contentWidth,
          contentHeight,
          scrollbarYHeight,
          scrollbarYTop,
          scrollbarYRight = parseInt($scrollbarY.css('right'), 10);

	  /**
	   *
	   */
      var updateContentScrollTop = function () {
        var scrollTop = parseInt(scrollbarYTop * (contentHeight - containerHeight) / (containerHeight - scrollbarYHeight), 10);
        $this.scrollTop(scrollTop);
      };


	  /**
	   *
	   */
      var getSettingsAdjustedThumbSize = function (thumbSize) {
        if (settings.minScrollbarLength) {
          thumbSize = Math.max(thumbSize, settings.minScrollbarLength);
        }
        return thumbSize;
      };


	  /**
	   *
	   */
      var updateScrollbarCss = function () {
        $scrollbarY.css({
			top: scrollbarYTop + $this.scrollTop(),
			right: scrollbarYRight - $this.scrollLeft(),
			height: scrollbarYHeight
		});
      };


	  /**
	   *
	   */
      var updateBarSizeAndPosition = function () {
        containerWidth = $this.width();
        containerHeight = $this.height();
        contentWidth = $this.prop('scrollWidth');
        contentHeight = $this.prop('scrollHeight');

        if (containerHeight < contentHeight) {
          scrollbarYHeight = getSettingsAdjustedThumbSize(parseInt(containerHeight * containerHeight / contentHeight, 10));
          scrollbarYTop = parseInt($this.scrollTop() * (containerHeight - scrollbarYHeight) / (contentHeight - containerHeight), 10);
        }
        else {
          scrollbarYHeight = 0;
          scrollbarYTop = 0;
          $this.scrollTop(0);
        }

        if (scrollbarYTop >= containerHeight - scrollbarYHeight) {
          scrollbarYTop = containerHeight - scrollbarYHeight;
        }

        updateScrollbarCss();
      };


	  /**
	   *
	   */
      var moveBarY = function (currentTop, deltaY) {
        var newTop = currentTop + deltaY,
            maxTop = containerHeight - scrollbarYHeight;

        if (newTop < 0) {
          scrollbarYTop = 0;
        }
        else if (newTop > maxTop) {
          scrollbarYTop = maxTop;
        }
        else {
          scrollbarYTop = newTop;
        }
        $scrollbarY.css({top: scrollbarYTop + $this.scrollTop()});
      };


	  /*
	   *
	   */
      var bindMouseScrollYHandler = function () {
        var currentTop,
            currentPageY;

        $scrollbarY.bind('mousedown.perfect-scroll', function (e) {
          currentPageY = e.pageY;
          currentTop = $scrollbarY.position().top;
          $scrollbarY.addClass('in-scrolling');
          e.stopPropagation();
          e.preventDefault();
        });

        $(document).bind('mousemove.perfect-scroll', function (e) {
          if ($scrollbarY.hasClass('in-scrolling')) {
            updateContentScrollTop();
            moveBarY(currentTop, e.pageY - currentPageY);
            e.stopPropagation();
            e.preventDefault();
          }
        });

        $(document).bind('mouseup.perfect-scroll', function (e) {
          if ($scrollbarY.hasClass('in-scrolling')) {
            $scrollbarY.removeClass('in-scrolling');
          }
        });

        currentTop =
        currentPageY = null;
      };


	  /**
	   * bind handlers
	   */
      var bindMouseWheelHandler = function () {
        var shouldPreventDefault = function (deltaX, deltaY) {
          var scrollTop = $this.scrollTop();
          if (scrollTop === 0 && deltaY > 0 && deltaX === 0) {
            return !settings.wheelPropagation;
          }
          else if (scrollTop >= contentHeight - containerHeight && deltaY < 0 && deltaX === 0) {
            return !settings.wheelPropagation;
          }

          var scrollLeft = $this.scrollLeft();
          if (scrollLeft === 0 && deltaX < 0 && deltaY === 0) {
            return !settings.wheelPropagation;
          }
          else if (scrollLeft >= contentWidth - containerWidth && deltaX > 0 && deltaY === 0) {
            return !settings.wheelPropagation;
          }
          return true;
        };

        var shouldPrevent = false;
        $this.bind('mousewheel.perfect-scroll', function (e, delta, deltaX, deltaY) {
          $this.scrollTop($this.scrollTop() - (deltaY * settings.wheelSpeed));
          $this.scrollLeft($this.scrollLeft() + (deltaX * settings.wheelSpeed));

          // update bar position
          updateBarSizeAndPosition();

          shouldPrevent = shouldPreventDefault(deltaX, deltaY);
          if (shouldPrevent) {
            e.preventDefault();
          }
        });

        // fix Firefox scroll problem
        $this.bind('MozMousePixelScroll.perfect-scroll', function (e) {
          if (shouldPrevent) {
            e.preventDefault();
          }
        });
      };


	  /**
	   *
	   */
      var destroy = function () {
        $this.unbind('.perfect-scroll');
        $(window).unbind('.perfect-scroll');
        $this.data('perfect-scrollbar', null);
        $this.data('perfect-scrollbar-update', null);
        $this.data('perfect-scrollbar-destroy', null);
        $scrollbarY.remove();

        // clean all variables
        $scrollbarY =
        containerWidth =
        containerHeight =
        contentWidth =
        contentHeight =
        scrollbarYHeight =
        scrollbarYTop =
        scrollbarYRight = null;
      };


	  /**
	   *
	   */
      var initialize = function () {
        updateBarSizeAndPosition();
        bindMouseScrollYHandler();
        if ($this.mousewheel) {
          bindMouseWheelHandler();
        }
        $this.data('perfect-scrollbar', $this);
        $this.data('perfect-scrollbar-update', updateBarSizeAndPosition);
        $this.data('perfect-scrollbar-destroy', destroy);
      };

      // initialize
      initialize();

      return $this;
    });
  };
})(jQuery));
