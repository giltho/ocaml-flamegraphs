(function() {
  "use strict";
  
  var svg = null;
  var frames = null;
  var searchInput = null;
  var matchCount = null;
  var details = null;
  var currentRoot = null;
  var originalTransforms = new Map();
  var originalWidths = new Map();
  var originalNames = new Map();
  
  var MIN_WIDTH_FOR_TEXT = 30;
  var TEXT_PADDING = 6; // 3px on each side
  
  function init() {
    svg = document.querySelector("svg.flamegraph");
    if (!svg) return;
    
    frames = svg.querySelectorAll("g.frame");
    searchInput = svg.querySelector("#search-input");
    matchCount = svg.querySelector("#match-count");
    details = svg.querySelector("#details");
    
    // Store original transforms, widths, and full text names
    frames.forEach(function(frame) {
      var rect = frame.querySelector("rect");
      var text = frame.querySelector("text");
      originalTransforms.set(frame, frame.getAttribute("transform") || "");
      originalWidths.set(rect, parseFloat(rect.getAttribute("width")));
      if (text) {
        originalNames.set(text, text.textContent);
      }
    });
    
    // Set up event handlers
    frames.forEach(function(frame) {
      frame.addEventListener("click", handleClick);
      frame.addEventListener("mouseover", handleMouseOver);
      frame.addEventListener("mouseout", handleMouseOut);
    });
    
    if (searchInput) {
      searchInput.addEventListener("input", handleSearch);
    }
    
    var resetBtn = svg.querySelector("#reset-zoom");
    if (resetBtn) {
      resetBtn.addEventListener("click", resetZoom);
    }
    
    // Initial text truncation for all frames
    updateAllText();
  }
  
  function handleClick(e) {
    e.stopPropagation();
    var frame = e.currentTarget;
    zoom(frame);
  }
  
  function handleMouseOver(e) {
    var frame = e.currentTarget;
    var rect = frame.querySelector("rect");
    var title = frame.querySelector("title");
    if (details && title) {
      details.textContent = title.textContent;
    }
    rect.style.stroke = "#000";
    rect.style.strokeWidth = "1";
  }
  
  function handleMouseOut(e) {
    var frame = e.currentTarget;
    var rect = frame.querySelector("rect");
    rect.style.stroke = "";
    rect.style.strokeWidth = "";
    if (details) {
      details.textContent = "";
    }
  }
  
  function getFrameData(frame) {
    var rect = frame.querySelector("rect");
    var transform = originalTransforms.get(frame) || "";
    var match = transform.match(/translate\(([\d.]+),\s*([\d.]+)\)/);
    var x = match ? parseFloat(match[1]) : 0;
    var y = match ? parseFloat(match[2]) : 0;
    var width = originalWidths.get(rect) || parseFloat(rect.getAttribute("width"));
    return { x: x, y: y, width: width, frame: frame };
  }
  
  /**
   * Truncate text to fit within available width using binary search.
   * Uses getComputedTextLength for accurate measurement.
   */
  function truncateText(text, availableWidth) {
    var fullName = originalNames.get(text);
    if (!fullName) return;
    
    // First, try with full name
    text.textContent = fullName;
    var textWidth = text.getComputedTextLength();
    
    if (textWidth <= availableWidth) {
      // Full name fits
      return;
    }
    
    // Need to truncate - use binary search to find optimal length
    var ellipsis = "..";
    var lo = 0;
    var hi = fullName.length;
    
    while (lo < hi) {
      var mid = Math.ceil((lo + hi) / 2);
      text.textContent = fullName.substring(0, mid) + ellipsis;
      textWidth = text.getComputedTextLength();
      
      if (textWidth <= availableWidth) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    
    if (lo === 0) {
      // Can't fit even one character + ellipsis
      text.textContent = "";
    } else {
      text.textContent = fullName.substring(0, lo) + ellipsis;
    }
  }
  
  /**
   * Update text visibility and truncation for a single frame.
   */
  function updateFrameText(frame, rectWidth) {
    var text = frame.querySelector("text");
    if (!text) return;
    
    if (rectWidth < MIN_WIDTH_FOR_TEXT) {
      text.style.display = "none";
    } else {
      text.style.display = "";
      var availableWidth = rectWidth - TEXT_PADDING;
      truncateText(text, availableWidth);
    }
  }
  
  /**
   * Update text for all visible frames based on their current widths.
   */
  function updateAllText() {
    frames.forEach(function(frame) {
      if (frame.style.display === "none") return;
      var rect = frame.querySelector("rect");
      var rectWidth = parseFloat(rect.getAttribute("width"));
      updateFrameText(frame, rectWidth);
    });
  }
  
  function zoom(targetFrame) {
    var target = getFrameData(targetFrame);
    currentRoot = targetFrame;
    
    var svgWidth = parseFloat(svg.getAttribute("width")) - 20; // margins
    var svgHeight = parseFloat(svg.getAttribute("height"));
    var scale = svgWidth / target.width;
    var offsetX = target.x;
    var targetY = target.y;
    
    frames.forEach(function(frame) {
      var data = getFrameData(frame);
      var rect = frame.querySelector("rect");
      
      // Check if this frame is in the zoomed subtree
      var newX = (data.x - offsetX) * scale + 10;
      var newWidth = data.width * scale;
      
      // Hide frames outside the zoomed view
      // In bottom-up layout: hide frames below target (y > targetY) or outside x bounds
      if (data.y > targetY || newX + newWidth < 10 || newX > svgWidth + 10) {
        frame.style.display = "none";
      } else {
        frame.style.display = "";
        // Keep y position relative, shift so target ends up at bottom of graph area
        var newY = data.y + (svgHeight - 30 - 16) - targetY;
        frame.setAttribute("transform", "translate(" + newX + "," + newY + ")");
        rect.setAttribute("width", Math.max(0.5, newWidth));
        
        // Update text with new width
        updateFrameText(frame, newWidth);
      }
    });
  }
  
  function resetZoom() {
    currentRoot = null;
    frames.forEach(function(frame) {
      var rect = frame.querySelector("rect");
      var originalWidth = originalWidths.get(rect);
      frame.style.display = "";
      frame.setAttribute("transform", originalTransforms.get(frame) || "");
      rect.setAttribute("width", originalWidth);
      
      // Update text with original width
      updateFrameText(frame, originalWidth);
    });
  }
  
  function handleSearch() {
    var query = searchInput.value.toLowerCase().trim();
    var count = 0;
    
    frames.forEach(function(frame) {
      var rect = frame.querySelector("rect");
      var title = frame.querySelector("title");
      var name = title ? title.textContent.toLowerCase() : "";
      
      if (query && name.indexOf(query) !== -1) {
        rect.style.fill = "#ffff00";
        count++;
      } else {
        rect.style.fill = "";
      }
    });
    
    if (matchCount) {
      matchCount.textContent = query ? count + " matches" : "";
    }
  }
  
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
