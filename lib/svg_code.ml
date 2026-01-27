(** SVG code fragments - CSS, JavaScript, and template functions.
    
    Static content is loaded from external files via ppx_blob.
    Dynamic templates that require variables are defined as functions. *)

(** CSS styles loaded from flamegraph.css *)
let css : string = [%blob "flamegraph.css"]

(** JavaScript code loaded from flamegraph.js *)
let js : string = [%blob "flamegraph.js"]

(** Wrap CSS in a style element *)
let style_element () =
  Printf.sprintf "<style>\n%s</style>" css

(** Wrap JavaScript in a script element with CDATA for SVG *)
let script_element () =
  Printf.sprintf {|<script type="text/javascript">
<![CDATA[
%s
]]>
</script>|} js

(** SVG header template *)
let svg_header ~width ~height ~background =
  Printf.sprintf
    {|<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg class="flamegraph" version="1.1" width="%d" height="%d" xmlns="http://www.w3.org/2000/svg">
%s
<rect x="0" y="0" width="100%%" height="100%%" fill="%s"/>
|}
    width height (style_element ()) background

(** Title and controls template *)
let controls ~font_family ~title ~width ~margin ~details_y =
  Printf.sprintf
    {|<text x="10" y="24" font-size="16" font-family="%s" font-weight="bold" fill="#000">%s</text>
<text x="%d" y="24" font-size="12" font-family="%s" fill="#666" text-anchor="end" id="reset-zoom" style="cursor:pointer">[Reset Zoom]</text>
<text x="10" y="42" font-size="12" font-family="%s" fill="#666">Search: </text>
<foreignObject x="60" y="28" width="200" height="20">
<input xmlns="http://www.w3.org/1999/xhtml" id="search-input" type="text" style="width:190px;font-size:11px;border:1px solid #ccc;padding:2px;"/>
</foreignObject>
<text x="270" y="42" font-size="11" font-family="%s" fill="#888" id="match-count"></text>
<text x="10" y="%d" font-size="11" font-family="%s" fill="#666" id="details"></text>
|}
    font_family title
    (width - margin) font_family
    font_family font_family
    details_y font_family

(** SVG footer with script *)
let svg_footer () =
  Printf.sprintf "%s\n</svg>\n" (script_element ())
