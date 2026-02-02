(** Tests for the flamegraphs library using Alcotest. *)

open Flamegraphs

(** {1 Custom Testables} *)

let float_epsilon = 0.001
let float_eq a b = abs_float (a -. b) < float_epsilon

let float_testable =
  Alcotest.testable (fun fmt f -> Format.fprintf fmt "%.6f" f) float_eq

(** {1 Flamegraph Tests} *)

let test_empty () =
  let fg = Flamegraph.empty in
  Alcotest.(check bool) "empty should be empty" true (Flamegraph.is_empty fg);
  Alcotest.(check float_testable)
    "total_weight" 0.0
    (Flamegraph.total_weight fg);
  Alcotest.(check int) "depth" 0 (Flamegraph.depth fg)

let test_single_stack () =
  let stack =
    Flamegraph.stack_of_strings ~weight:10.0 [ "main"; "foo"; "bar" ]
  in
  let fg = Flamegraph.of_stacks [ stack ] in
  Alcotest.(check bool) "should not be empty" false (Flamegraph.is_empty fg);
  Alcotest.(check float_testable)
    "total_weight" 10.0
    (Flamegraph.total_weight fg);
  Alcotest.(check int) "depth" 3 (Flamegraph.depth fg)

let test_merging_stacks () =
  let fg =
    Flamegraph.of_stacks
      [
        Flamegraph.stack_of_strings ~weight:10.0 [ "main"; "foo"; "bar" ];
        Flamegraph.stack_of_strings ~weight:5.0 [ "main"; "foo"; "baz" ];
        Flamegraph.stack_of_strings ~weight:3.0 [ "main"; "qux" ];
      ]
  in
  Alcotest.(check float_testable)
    "total_weight" 18.0
    (Flamegraph.total_weight fg);
  let roots = Flamegraph.roots fg in
  Alcotest.(check int) "root count" 1 (List.length roots);
  let root = List.hd roots in
  Alcotest.(check string) "root name" "main" root.frame.name;
  Alcotest.(check float_testable) "root total_weight" 18.0 root.total_weight

let test_frame_with_metadata () =
  let frame =
    Flamegraph.frame ~metadata:[ ("file", "test.ml"); ("line", "42") ] "my_func"
  in
  Alcotest.(check string) "frame name" "my_func" frame.name;
  Alcotest.(check int) "metadata length" 2 (List.length frame.metadata);
  Alcotest.(check string)
    "file metadata" "test.ml"
    (List.assoc "file" frame.metadata)

let test_iteration () =
  let fg =
    Flamegraph.of_stacks
      [
        Flamegraph.stack_of_strings ~weight:10.0 [ "main"; "foo" ];
        Flamegraph.stack_of_strings ~weight:5.0 [ "main"; "bar" ];
      ]
  in
  let count = ref 0 in
  let total = ref 0.0 in
  Flamegraph.iter
    (fun _frames weight ->
      incr count;
      total := !total +. weight)
    fg;
  Alcotest.(check int) "stack count" 2 !count;
  Alcotest.(check float_testable) "total weight" 15.0 !total

let flamegraph_tests =
  [
    Alcotest.test_case "empty flamegraph" `Quick test_empty;
    Alcotest.test_case "single stack" `Quick test_single_stack;
    Alcotest.test_case "merging stacks with common prefix" `Quick
      test_merging_stacks;
    Alcotest.test_case "frame with metadata" `Quick test_frame_with_metadata;
    Alcotest.test_case "iteration over stacks" `Quick test_iteration;
  ]

(** {1 Tree-based Construction Tests} *)

let test_tree_single_node () =
  let open Flamegraph in
  let fg = of_tree (node "main" ~weight:10.0 []) in
  Alcotest.(check float_testable) "total_weight" 10.0 (total_weight fg);
  Alcotest.(check int) "depth" 1 (depth fg)

let test_tree_nested () =
  let open Flamegraph in
  let fg =
    of_tree
      (node "main" [ node "foo" ~weight:10.0 []; node "bar" ~weight:5.0 [] ])
  in
  Alcotest.(check float_testable) "total_weight" 15.0 (total_weight fg);
  Alcotest.(check int) "depth" 2 (depth fg);
  let roots = roots fg in
  Alcotest.(check int) "root count" 1 (List.length roots);
  let root = List.hd roots in
  Alcotest.(check string) "root name" "main" root.frame.name;
  Alcotest.(check int) "children count" 2 (List.length root.children)

let test_tree_deep () =
  let open Flamegraph in
  let fg =
    of_tree
      (node "main"
         [ node "level1" [ node "level2" [ node "level3" ~weight:100.0 [] ] ] ])
  in
  Alcotest.(check float_testable) "total_weight" 100.0 (total_weight fg);
  Alcotest.(check int) "depth" 4 (depth fg)

let test_tree_multiple_roots () =
  let open Flamegraph in
  let fg =
    of_trees [ node "thread1" ~weight:10.0 []; node "thread2" ~weight:20.0 [] ]
  in
  Alcotest.(check float_testable) "total_weight" 30.0 (total_weight fg);
  let roots = roots fg in
  Alcotest.(check int) "root count" 2 (List.length roots)

let test_tree_matches_stacks () =
  let open Flamegraph in
  let fg_tree =
    of_tree
      (node "main"
         [
           node "foo" [ node "bar" ~weight:10.0 [] ]; node "baz" ~weight:5.0 [];
         ])
  in
  let fg_stacks =
    of_stacks
      [
        stack_of_strings ~weight:10.0 [ "main"; "foo"; "bar" ];
        stack_of_strings ~weight:5.0 [ "main"; "baz" ];
      ]
  in
  Alcotest.(check float_testable)
    "total_weight should match" (total_weight fg_tree) (total_weight fg_stacks);
  Alcotest.(check int) "depth should match" (depth fg_tree) (depth fg_stacks)

let tree_tests =
  [
    Alcotest.test_case "single node" `Quick test_tree_single_node;
    Alcotest.test_case "nested nodes" `Quick test_tree_nested;
    Alcotest.test_case "deep nesting" `Quick test_tree_deep;
    Alcotest.test_case "multiple roots" `Quick test_tree_multiple_roots;
    Alcotest.test_case "matches stacks" `Quick test_tree_matches_stacks;
  ]

(** {1 Folded Format Tests} *)

let test_folded_export () =
  let fg =
    Flamegraph.of_stacks
      [
        Flamegraph.stack_of_strings ~weight:10.0 [ "main"; "foo"; "bar" ];
        Flamegraph.stack_of_strings ~weight:5.0 [ "main"; "baz" ];
      ]
  in
  let output = Folded.to_string fg in
  Alcotest.(check bool)
    "output should not be empty" true
    (String.length output > 0);
  let lines = String.split_on_char '\n' output in
  let non_empty = List.filter (fun s -> String.length s > 0) lines in
  Alcotest.(check int) "line count" 2 (List.length non_empty)

let test_folded_roundtrip () =
  let original =
    Flamegraph.of_stacks
      [
        Flamegraph.stack_of_strings ~weight:10.0 [ "main"; "foo"; "bar" ];
        Flamegraph.stack_of_strings ~weight:5.0 [ "main"; "baz" ];
      ]
  in
  let exported = Folded.to_string original in
  match Folded.of_string exported with
  | Error e -> Alcotest.fail ("parse error: " ^ e)
  | Ok reimported ->
      Alcotest.(check float_testable)
        "total_weight"
        (Flamegraph.total_weight original)
        (Flamegraph.total_weight reimported)

let test_folded_parse () =
  let input = "main;foo;bar 10\nmain;baz 5\n" in
  match Folded.of_string input with
  | Error e -> Alcotest.fail ("parse error: " ^ e)
  | Ok fg ->
      Alcotest.(check float_testable)
        "total_weight" 15.0
        (Flamegraph.total_weight fg)

let test_folded_parse_with_comments () =
  let input = "# This is a comment\nmain;foo 10\n\nmain;bar 5\n" in
  match Folded.of_string input with
  | Error e -> Alcotest.fail ("parse error: " ^ e)
  | Ok fg ->
      Alcotest.(check float_testable)
        "total_weight" 15.0
        (Flamegraph.total_weight fg)

let folded_tests =
  [
    Alcotest.test_case "export" `Quick test_folded_export;
    Alcotest.test_case "roundtrip" `Quick test_folded_roundtrip;
    Alcotest.test_case "parse" `Quick test_folded_parse;
    Alcotest.test_case "parse with comments" `Quick
      test_folded_parse_with_comments;
  ]

(** {1 SVG Tests} *)

(** Check if a string contains a substring *)
let contains haystack needle =
  let needle_len = String.length needle in
  let haystack_len = String.length haystack in
  if needle_len > haystack_len then false
  else
    let rec check i =
      if i + needle_len > haystack_len then false
      else if String.sub haystack i needle_len = needle then true
      else check (i + 1)
    in
    check 0

let test_svg_generation () =
  let fg =
    Flamegraph.of_stacks
      [
        Flamegraph.stack_of_strings ~weight:10.0 [ "main"; "foo"; "bar" ];
        Flamegraph.stack_of_strings ~weight:5.0 [ "main"; "baz" ];
      ]
  in
  let svg = Svg.to_string fg in
  Alcotest.(check bool)
    "should start with XML declaration" true
    (String.length svg > 0 && String.sub svg 0 5 = "<?xml");
  Alcotest.(check bool) "should contain svg tag" true (contains svg "<svg");
  Alcotest.(check bool)
    "should contain flamegraph class" true
    (contains svg "flamegraph")

let test_svg_with_config () =
  let fg =
    Flamegraph.of_stacks
      [ Flamegraph.stack_of_strings ~weight:10.0 [ "main"; "foo" ] ]
  in
  let config =
    Svg.config ~width:800 ~title:"Test Profile" ~color_scheme:Cold ()
  in
  let svg = Svg.to_string ~config fg in
  Alcotest.(check bool)
    "should have custom width" true
    (contains svg "width=\"800\"");
  Alcotest.(check bool) "should have title" true (contains svg "Test Profile")

let test_svg_escaping () =
  let fg =
    Flamegraph.of_stacks
      [
        Flamegraph.stack_of_strings ~weight:1.0
          [ "main"; "foo<bar>"; "test&value" ];
      ]
  in
  let svg = Svg.to_string fg in
  Alcotest.(check bool) "should escape < as &lt;" true (contains svg "&lt;");
  Alcotest.(check bool) "should escape & as &amp;" true (contains svg "&amp;")

let test_svg_javascript () =
  let fg =
    Flamegraph.of_stacks [ Flamegraph.stack_of_strings ~weight:1.0 [ "main" ] ]
  in
  let svg = Svg.to_string fg in
  Alcotest.(check bool)
    "should contain script tag" true (contains svg "<script");
  Alcotest.(check bool)
    "should contain zoom function" true
    (contains svg "function zoom")

let svg_tests =
  [
    Alcotest.test_case "generation" `Quick test_svg_generation;
    Alcotest.test_case "with config" `Quick test_svg_with_config;
    Alcotest.test_case "XML escaping" `Quick test_svg_escaping;
    Alcotest.test_case "contains JavaScript" `Quick test_svg_javascript;
  ]

(** {1 Main} *)

let () =
  Alcotest.run "flamegraphs"
    [
      ("Flamegraph", flamegraph_tests);
      ("Tree construction", tree_tests);
      ("Folded format", folded_tests);
      ("SVG", svg_tests);
    ]
