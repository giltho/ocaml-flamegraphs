(** OCaml Flamegraph Library

    A library for programmatically constructing flamegraphs and exporting
    them to SVG or folded stacks format.

    {1 Quick Start}

    {[
      open Flamegraphs

      (* Create a flamegraph from stack traces *)
      let fg =
        Flamegraph.of_stacks
          [
            Flamegraph.stack_of_strings ~weight:10.0 [ "main"; "process"; "compute" ];
            Flamegraph.stack_of_strings ~weight:5.0 [ "main"; "process"; "allocate" ];
            Flamegraph.stack_of_strings ~weight:3.0 [ "main"; "init" ];
          ]

      (* Export to SVG *)
      let () =
        match Svg.to_file "profile.svg" fg with
        | Ok () -> print_endline "SVG written"
        | Error e -> print_endline ("Error: " ^ e)

      (* Export to folded stacks format *)
      let () =
        match Folded.to_file "profile.folded" fg with
        | Ok () -> print_endline "Folded stacks written"
        | Error e -> print_endline ("Error: " ^ e)
    ]}

    {1 Modules} *)

(** Core flamegraph data structure and construction API. *)
module Flamegraph = Flamegraph

(** SVG rendering with interactive JavaScript. *)
module Svg = Svg

(** Folded stacks format import/export (compatible with flamegraph.pl). *)
module Folded = Folded
