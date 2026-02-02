(** Folded stacks format implementation. *)

(** {1 Configuration} *)

type weight_format = Integer | Float of int
type config = { separator : string; weight_format : weight_format }

let default_config = { separator = ";"; weight_format = Float 2 }

let config ?(separator = default_config.separator)
    ?(weight_format = default_config.weight_format) () =
  { separator; weight_format }

(** {1 Helpers} *)

(** Format a weight according to the config. *)
let format_weight cfg w =
  match cfg.weight_format with
  | Integer -> Printf.sprintf "%d" (int_of_float (w +. 0.5))
  | Float n -> Printf.sprintf "%.*f" n w

(** Split a string by a separator (not using Str to avoid dependency). *)
let split_on_string ~sep s =
  let sep_len = String.length sep in
  if sep_len = 0 then [ s ]
  else
    let rec loop acc start =
      match String.index_from_opt s start sep.[0] with
      | None -> List.rev (String.sub s start (String.length s - start) :: acc)
      | Some i ->
          if i + sep_len <= String.length s && String.sub s i sep_len = sep then
            let part = String.sub s start (i - start) in
            loop (part :: acc) (i + sep_len)
          else loop acc (i + 1)
    in
    loop [] 0

(** {1 Export} *)

let to_string ?(config = default_config) fg =
  let buf = Buffer.create 4096 in
  Flamegraph.iter
    (fun frames self_weight ->
      if self_weight > 0.0 then begin
        let names = List.map (fun f -> f.Flamegraph.name) frames in
        let stack_str = String.concat config.separator names in
        let weight_str = format_weight config self_weight in
        Buffer.add_string buf stack_str;
        Buffer.add_char buf ' ';
        Buffer.add_string buf weight_str;
        Buffer.add_char buf '\n'
      end)
    fg;
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
  with Sys_error msg -> Error msg

(** {1 Import} *)

(** Parse a single line of folded stacks format. *)
let parse_line ~config ~line_num line =
  let line = String.trim line in
  if line = "" || (String.length line > 0 && line.[0] = '#') then
    (* Empty line or comment *)
    Ok None
  else
    (* Find the last space - everything before is the stack, after is the weight *)
    match String.rindex_opt line ' ' with
    | None ->
        Error
          (Printf.sprintf "Line %d: missing weight (no space found)" line_num)
    | Some space_idx -> (
        let stack_part = String.sub line 0 space_idx in
        let weight_part =
          String.sub line (space_idx + 1) (String.length line - space_idx - 1)
        in
        match float_of_string_opt weight_part with
        | None ->
            Error
              (Printf.sprintf "Line %d: invalid weight '%s'" line_num
                 weight_part)
        | Some weight ->
            let frame_names =
              split_on_string ~sep:config.separator stack_part
            in
            let frames = List.map Flamegraph.frame frame_names in
            let stack = Flamegraph.stack ~weight frames in
            Ok (Some stack))

let of_string ?(config = default_config) s =
  let lines = String.split_on_char '\n' s in
  let rec loop acc line_num = function
    | [] -> Ok (Flamegraph.of_stacks (List.rev acc))
    | line :: rest -> (
        match parse_line ~config ~line_num line with
        | Error e -> Error e
        | Ok None -> loop acc (line_num + 1) rest
        | Ok (Some stack) -> loop (stack :: acc) (line_num + 1) rest)
  in
  loop [] 1 lines

let of_channel ?(config = default_config) ic =
  try
    let buf = Buffer.create 4096 in
    (try
       while true do
         Buffer.add_string buf (input_line ic);
         Buffer.add_char buf '\n'
       done
     with End_of_file -> ());
    of_string ~config (Buffer.contents buf)
  with Sys_error msg -> Error msg

let of_file ?(config = default_config) path =
  try
    let ic = open_in path in
    Fun.protect
      ~finally:(fun () -> close_in ic)
      (fun () -> of_channel ~config ic)
  with Sys_error msg -> Error msg
