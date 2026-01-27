(** Flamegraph data structure and construction API. *)

(** {1 Types} *)

type frame = {
  name : string;
  metadata : (string * string) list;
}

type stack = {
  frames : frame list;
  weight : float;
}

(** Internal node representation *)
type node = {
  frame : frame;
  self_weight : float;
  total_weight : float;
  children : node list;
}

type t = {
  roots : node list;
  total_weight : float;
}

(** {1 Construction} *)

let empty = { roots = []; total_weight = 0.0 }

let frame ?(metadata = []) name = { name; metadata }

let stack ?(weight = 1.0) frames = { frames; weight }

let stack_of_strings ?(weight = 1.0) names =
  { frames = List.map (fun name -> { name; metadata = [] }) names; weight }

(** Find a child node by frame name *)
let find_child frame children =
  List.find_opt (fun n -> n.frame.name = frame.name) children

(** Insert a stack into a list of nodes, returning updated nodes *)
let rec insert_into_nodes frames weight nodes =
  match frames with
  | [] -> nodes
  | frame :: rest ->
    (* Find if this frame already exists, preserving order *)
    let rec update_or_append = function
      | [] ->
        (* Create new node at the end *)
        let self_weight = if rest = [] then weight else 0.0 in
        let children = insert_into_nodes rest weight [] in
        [{
          frame;
          self_weight;
          total_weight = weight;
          children;
        }]
      | node :: tail when node.frame.name = frame.name ->
        (* Update existing node, keep position *)
        let self_weight =
          if rest = [] then node.self_weight +. weight
          else node.self_weight
        in
        let children = insert_into_nodes rest weight node.children in
        { node with self_weight; total_weight = node.total_weight +. weight; children } :: tail
      | node :: tail ->
        node :: update_or_append tail
    in
    update_or_append nodes

let add_stack { frames; weight } fg =
  if weight <= 0.0 || frames = [] then fg
  else
    let roots = insert_into_nodes frames weight fg.roots in
    { roots; total_weight = fg.total_weight +. weight }

let add_stacks stacks fg =
  List.fold_left (fun fg s -> add_stack s fg) fg stacks

let of_stacks stacks = add_stacks stacks empty

(** {1 Accessors} *)

let roots fg = fg.roots

let total_weight fg = fg.total_weight

let is_empty fg = fg.roots = []

let rec node_depth node =
  match node.children with
  | [] -> 1
  | children -> 1 + List.fold_left (fun m c -> max m (node_depth c)) 0 children

let depth fg =
  List.fold_left (fun m n -> max m (node_depth n)) 0 fg.roots

(** {1 Iteration} *)

let iter f fg =
  let rec iter_node path node =
    let current_path = path @ [ node.frame ] in
    if node.self_weight > 0.0 then f current_path node.self_weight;
    List.iter (iter_node current_path) node.children
  in
  List.iter (iter_node []) fg.roots

let fold f fg acc =
  let rec fold_node path acc node =
    let current_path = path @ [ node.frame ] in
    let acc =
      if node.self_weight > 0.0 then f current_path node.self_weight acc
      else acc
    in
    List.fold_left (fold_node current_path) acc node.children
  in
  List.fold_left (fold_node []) acc fg.roots

(** {1 Tree-based Construction} *)

type tree =
  | Node of {
      t_frame : frame;
      t_weight : float;
      t_children : tree list;
    }

let node ?(metadata = []) ?(weight = 0.0) name children =
  Node { t_frame = { name; metadata }; t_weight = weight; t_children = children }

(** Convert a tree to internal node representation, computing total_weight *)
let rec tree_to_node (Node { t_frame; t_weight; t_children }) =
  let child_nodes = List.map tree_to_node t_children in
  let children_weight = List.fold_left (fun acc (n : node) -> acc +. n.total_weight) 0.0 child_nodes in
  {
    frame = t_frame;
    self_weight = t_weight;
    total_weight = t_weight +. children_weight;
    children = child_nodes;
  }

let of_tree tree =
  let root_node = tree_to_node tree in
  { roots = [ root_node ]; total_weight = root_node.total_weight }

let of_trees trees =
  let root_nodes = List.map tree_to_node trees in
  let total = List.fold_left (fun acc (n : node) -> acc +. n.total_weight) 0.0 root_nodes in
  { roots = root_nodes; total_weight = total }
