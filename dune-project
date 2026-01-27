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
 (synopsis "A library for manipulating flamegraphs")
 (depends
  ocaml
  (alcotest :with-test))
 (tags
  ("flamegraph" "perf" "visualization" "profiling")))
