(** SVG rendering for flamegraphs. *)

(** {1 Configuration} *)

type color_scheme =
  | Hot
  | Cold
  | Memory
  | Io
  | Custom of (Flamegraph.frame -> depth:int -> string)

type config = {
  width : int;
  row_height : int;
  font_size : int;
  font_family : string;
  min_width_for_text : float;
  color_scheme : color_scheme;
  title : string option;
  background : string;
}

let default_config =
  {
    width = 1200;
    row_height = 16;
    font_size = 12;
    font_family = "monospace";
    min_width_for_text = 0.02;
    color_scheme = Hot;
    title = None;
    background = "#f8f8f8";
  }

let config
    ?(width = default_config.width)
    ?(row_height = default_config.row_height)
    ?(font_size = default_config.font_size)
    ?(font_family = default_config.font_family)
    ?(min_width_for_text = default_config.min_width_for_text)
    ?(color_scheme = default_config.color_scheme)
    ?title
    ?(background = default_config.background)
    () =
  { width; row_height; font_size; font_family; min_width_for_text; color_scheme; title; background }

(** {1 Helpers} *)

(** Escape special characters for XML/SVG. *)
let escape_xml s =
  let buf = Buffer.create (String.length s) in
  String.iter
    (function
      | '<' -> Buffer.add_string buf "&lt;"
      | '>' -> Buffer.add_string buf "&gt;"
      | '&' -> Buffer.add_string buf "&amp;"
      | '"' -> Buffer.add_string buf "&quot;"
      | '\'' -> Buffer.add_string buf "&#39;"
      | c -> Buffer.add_char buf c)
    s;
  Buffer.contents buf

(** Get color for a frame based on color scheme. *)
let get_color scheme frame ~depth =
  match scheme with
  | Hot -> Color.hot frame.Flamegraph.name
  | Cold -> Color.cold frame.Flamegraph.name
  | Memory -> Color.memory frame.Flamegraph.name
  | Io -> Color.io frame.Flamegraph.name
  | Custom f -> f frame ~depth

(** JavaScript code for interactivity. *)
let javascript = {|
<script type="text/javascript">
<![CDATA[
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
  
  function init() {
    svg = document.querySelector("svg.flamegraph");
    if (!svg) return;
    
    frames = svg.querySelectorAll("g.frame");
    searchInput = svg.querySelector("#search-input");
    matchCount = svg.querySelector("#match-count");
    details = svg.querySelector("#details");
    
    // Store original transforms and widths
    frames.forEach(function(frame) {
      var rect = frame.querySelector("rect");
      originalTransforms.set(frame, frame.getAttribute("transform") || "");
      originalWidths.set(rect, parseFloat(rect.getAttribute("width")));
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
      var text = frame.querySelector("text");
      
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
        
        // Update text visibility
        if (text) {
          if (newWidth < 30) {
            text.style.display = "none";
          } else {
            text.style.display = "";
          }
        }
      }
    });
  }
  
  function resetZoom() {
    currentRoot = null;
    frames.forEach(function(frame) {
      var rect = frame.querySelector("rect");
      var text = frame.querySelector("text");
      frame.style.display = "";
      frame.setAttribute("transform", originalTransforms.get(frame) || "");
      rect.setAttribute("width", originalWidths.get(rect));
      if (text) text.style.display = "";
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
]]>
</script>
|}

(** {1 Rendering} *)

(** Render a single frame as SVG group. *)
let render_frame buf cfg ~total_weight ~x ~y ~width ~depth (node : Flamegraph.node) =
  let color = get_color cfg.color_scheme node.frame ~depth in
  let name = escape_xml node.frame.name in
  let pct = if total_weight > 0.0 then node.total_weight /. total_weight *. 100.0 else 0.0 in
  let title =
    Printf.sprintf "%s (%.2f, %.2f%%)"
      name
      node.total_weight
      pct
  in
  let text_visible = width >= float_of_int cfg.width *. cfg.min_width_for_text in
  
  Printf.bprintf buf
    {|<g class="frame" transform="translate(%.2f,%.2f)">
<title>%s</title>
<rect x="0" y="0" width="%.2f" height="%d" fill="%s" rx="2" ry="2"/>
|}
    x y title width (cfg.row_height - 1) color;
  
  if text_visible then begin
    let max_chars = int_of_float (width /. (float_of_int cfg.font_size *. 0.6)) in
    let display_name =
      if String.length name > max_chars && max_chars > 3 then
        String.sub name 0 (max_chars - 2) ^ ".."
      else if String.length name > max_chars then
        ""
      else
        name
    in
    if display_name <> "" then
      Printf.bprintf buf
        {|<text x="3" y="%d" font-size="%d" font-family="%s" fill="#000">%s</text>
|}
        (cfg.row_height - 4) cfg.font_size cfg.font_family display_name
  end;
  
  Buffer.add_string buf "</g>\n"

(** Recursively render nodes. Renders from bottom up (flames grow upward). *)
let rec render_nodes buf cfg ~total_weight ~x ~y ~depth ~width_scale nodes =
  List.iter
    (fun (node : Flamegraph.node) ->
      let node_width = node.total_weight *. width_scale in
      if node_width >= 0.5 then begin
        render_frame buf cfg ~total_weight ~x ~y ~width:node_width ~depth node;
        (* Render children above (smaller y value) *)
        let child_y = y -. float_of_int cfg.row_height in
        let child_x = ref x in
        List.iter
          (fun (child : Flamegraph.node) ->
            render_nodes buf cfg ~total_weight ~x:!child_x ~y:child_y ~depth:(depth + 1) ~width_scale [ child ];
            child_x := !child_x +. child.total_weight *. width_scale)
          node.children
      end)
    nodes

let to_string ?(config = default_config) fg =
  let buf = Buffer.create 65536 in
  let total = Flamegraph.total_weight fg in
  let graph_depth = Flamegraph.depth fg in
  let margin = 10 in
  let header_height = 60 in
  let graph_height = graph_depth * config.row_height in
  let total_height = header_height + graph_height + 30 in
  let usable_width = float_of_int (config.width - 2 * margin) in
  let width_scale = if total > 0.0 then usable_width /. total else 0.0 in
  
  (* SVG header *)
  Printf.bprintf buf
    {|<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg class="flamegraph" version="1.1" width="%d" height="%d" xmlns="http://www.w3.org/2000/svg">
<style>
  .frame { cursor: pointer; }
  .frame:hover rect { stroke: #000; stroke-width: 1; }
  text { pointer-events: none; }
</style>
<rect x="0" y="0" width="100%%" height="100%%" fill="%s"/>
|}
    config.width total_height config.background;
  
  (* Title and controls *)
  let title_text =
    match config.title with
    | Some t -> escape_xml t
    | None -> "Flame Graph"
  in
  Printf.bprintf buf
    {|<text x="10" y="24" font-size="16" font-family="%s" font-weight="bold" fill="#000">%s</text>
<text x="%d" y="24" font-size="12" font-family="%s" fill="#666" text-anchor="end" id="reset-zoom" style="cursor:pointer">[Reset Zoom]</text>
<text x="10" y="42" font-size="12" font-family="%s" fill="#666">Search: </text>
<foreignObject x="60" y="28" width="200" height="20">
<input xmlns="http://www.w3.org/1999/xhtml" id="search-input" type="text" style="width:190px;font-size:11px;border:1px solid #ccc;padding:2px;"/>
</foreignObject>
<text x="270" y="42" font-size="11" font-family="%s" fill="#888" id="match-count"></text>
<text x="10" y="%d" font-size="11" font-family="%s" fill="#666" id="details"></text>
|}
    config.font_family title_text
    (config.width - margin) config.font_family
    config.font_family config.font_family
    (total_height - 10) config.font_family;
  
  (* Render all frames - start from bottom, flames grow upward *)
  let roots = Flamegraph.roots fg in
  let root_y = float_of_int (header_height + graph_height - config.row_height) in
  let x = ref (float_of_int margin) in
  List.iter
    (fun (root : Flamegraph.node) ->
      render_nodes buf config ~total_weight:total ~x:!x ~y:root_y ~depth:0 ~width_scale [ root ];
      x := !x +. root.total_weight *. width_scale)
    roots;
  
  (* Add JavaScript *)
  Buffer.add_string buf javascript;
  
  (* Close SVG *)
  Buffer.add_string buf "</svg>\n";
  Buffer.contents buf

let to_channel ?(config = default_config) oc fg =
  output_string oc (to_string ~config fg)

let to_file ?(config = default_config) path fg =
  try
    let oc = open_out path in
    Fun.protect
      ~finally:(fun () -> close_out oc)
      (fun () -> to_channel ~config oc fg);
    Ok ()
  with
  | Sys_error msg -> Error msg
