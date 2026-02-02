(** Generates a sample SVG for diff testing. *)

open Flamegraphs

let () =
  let open Flamegraph in
  let fg =
    of_tree
      (node "main"
         [
           node "process_request"
             [
               node "parse_json"
                 [
                   node "tokenize" ~weight:100.0 [];
                   node "validate" ~weight:80.0 [];
                 ];
               node "handle_data"
                 [
                   node "compute" ~weight:150.0 [];
                   node "allocate" ~weight:50.0 [];
                 ];
             ];
           node "init"
             [
               node "load_config" ~weight:30.0 [];
               node "setup_logging" ~weight:20.0 [];
             ];
           node "cleanup" [ node "flush_buffers" ~weight:70.0 [] ];
         ])
  in
  let config = Svg.config ~title:"Test Flamegraph" ~width:800 () in
  print_string (Svg.to_string ~config fg)
