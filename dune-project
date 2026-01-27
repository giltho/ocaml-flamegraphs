(lang dune 3.21)

(name flamegraphs)

(generate_opam_files true)

(source
 (github giltho/ocaml-flamegraphs))

(authors "Sacha-Élie Ayoun <sachaayoun@gmail.com>")

(maintainers "Sacha-Élie Ayoun <sachaayoun@gmail.com>")

(license BSD-3-Clause)

(package
 (name flamegraphs)
 (synopsis "Build flamegraphs programmatically and export to SVG or folded stacks")
 (description
  "An OCaml library for constructing flamegraphs from stack traces or tree structures, with interactive SVG rendering and folded stacks format support compatible with flamegraph.pl.")
 (depends
  ocaml
  (alcotest :with-test))
 (tags
  (flamegraph profiling visualization svg performance)))
