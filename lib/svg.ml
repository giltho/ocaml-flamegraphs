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
  Buffer.add_string buf
    (Svg_code.svg_header ~width:config.width ~height:total_height ~background:config.background);
  
  (* Title and controls *)
  let title_text =
    match config.title with
    | Some t -> escape_xml t
    | None -> "Flame Graph"
  in
  Buffer.add_string buf
    (Svg_code.controls ~font_family:config.font_family ~title:title_text
       ~width:config.width ~margin ~details_y:(total_height - 10));
  
  (* Render all frames - start from bottom, flames grow upward *)
  let roots = Flamegraph.roots fg in
  let root_y = float_of_int (header_height + graph_height - config.row_height) in
  let x = ref (float_of_int margin) in
  List.iter
    (fun (root : Flamegraph.node) ->
      render_nodes buf config ~total_weight:total ~x:!x ~y:root_y ~depth:0 ~width_scale [ root ];
      x := !x +. root.total_weight *. width_scale)
    roots;
  
  (* Add JavaScript and close SVG *)
  Buffer.add_string buf (Svg_code.svg_footer ());
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
