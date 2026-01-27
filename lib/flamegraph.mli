(** Flamegraph data structure and construction API.

    This module provides the core types and functions for building flamegraphs
    programmatically from stack traces. *)

(** {1 Types} *)

(** A frame in the call stack. *)
type frame = {
  name : string;
      (** Function/method name. *)
  metadata : (string * string) list;
      (** Optional key-value metadata (e.g., file, line number). *)
}

(** A single stack trace with its weight. *)
type stack = {
  frames : frame list;
      (** Stack frames ordered bottom-to-top (caller to callee).
          The first element is the root/entry point, the last is the leaf. *)
  weight : float;
      (** Sample weight. Can represent count, time, bytes, or any metric. *)
}

(** The flamegraph data structure.

    Internally represented as a prefix tree (trie) for efficient
    merging of common stack prefixes. *)
type t

(** A node in the flamegraph tree, exposed for rendering. *)
type node = {
  frame : frame;
      (** The frame at this node. *)
  self_weight : float;
      (** Weight of stacks ending at this frame. *)
  total_weight : float;
      (** Total weight including all descendants. *)
  children : node list;
      (** Child nodes (callees). *)
}

(** {1 Construction} *)

val empty : t
(** The empty flamegraph with no stacks. *)

val add_stack : stack -> t -> t
(** [add_stack stack fg] adds a stack trace to the flamegraph.
    Stacks with the same frame sequence are merged by summing weights. *)

val add_stacks : stack list -> t -> t
(** [add_stacks stacks fg] adds multiple stack traces.
    Equivalent to [List.fold_left (fun fg s -> add_stack s fg) fg stacks]. *)

val of_stacks : stack list -> t
(** [of_stacks stacks] creates a flamegraph from a list of stack traces.
    Equivalent to [add_stacks stacks empty]. *)

(** {2 Convenience Constructors} *)

val frame : ?metadata:(string * string) list -> string -> frame
(** [frame name] creates a frame with the given name.
    @param metadata Optional key-value pairs for additional info. *)

val stack : ?weight:float -> frame list -> stack
(** [stack frames] creates a stack trace with weight [1.0].
    Frames should be ordered bottom-to-top (caller to callee).
    @param weight The weight/count for this stack. Default is [1.0]. *)

val stack_of_strings : ?weight:float -> string list -> stack
(** [stack_of_strings names] creates a stack from simple function names.
    Each string becomes a frame with no metadata.
    @param weight The weight/count for this stack. Default is [1.0]. *)

(** {2 Tree-based Construction}

    An alternative API for building flamegraphs using an explicit tree structure.
    This is often more natural when generating flamegraphs programmatically.

    Example:
    {[
      let fg = Flamegraph.of_tree
        (node "main" ~weight:0.0 [
          node "init" ~weight:30.0 [];
          node "process" ~weight:0.0 [
            node "parse" ~weight:100.0 [];
            node "compute" ~weight:150.0 [];
          ];
          node "cleanup" ~weight:70.0 [];
        ])
    ]}
*)

(** A tree node for constructing flamegraphs. Opaque type - use {!node} to construct. *)
type tree

val node : ?metadata:(string * string) list -> ?weight:float -> string -> tree list -> tree
(** [node name children] creates a tree node.
    @param metadata Optional key-value pairs for additional frame info.
    @param weight Self-weight at this node (time spent in this frame itself,
           not in children). Default is [0.0]. *)

val of_tree : tree -> t
(** [of_tree tree] creates a flamegraph from a single tree.
    The tree's root becomes the flamegraph's root. *)

val of_trees : tree list -> t
(** [of_trees trees] creates a flamegraph from multiple root trees.
    Use this when you have multiple entry points. *)

(** {1 Accessors} *)

val roots : t -> node list
(** [roots fg] returns the top-level nodes (entry points) of the flamegraph. *)

val total_weight : t -> float
(** [total_weight fg] returns the sum of all stack weights. *)

val is_empty : t -> bool
(** [is_empty fg] returns [true] if the flamegraph has no stacks. *)

val depth : t -> int
(** [depth fg] returns the maximum stack depth. *)

(** {1 Iteration} *)

val iter : (frame list -> float -> unit) -> t -> unit
(** [iter f fg] calls [f stack_frames self_weight] for each unique
    stack in the flamegraph where self_weight > 0. *)

val fold : (frame list -> float -> 'a -> 'a) -> t -> 'a -> 'a
(** [fold f fg acc] folds over each unique stack with self_weight > 0. *)
