(** Color scheme implementations for flamegraph rendering.
    
    This module is internal and not exposed in the public API. *)

(** Color represented as RGB components (0-255). *)
type rgb = { r : int; g : int; b : int }

(** Convert RGB to CSS hex color string. *)
let to_hex { r; g; b } =
  Printf.sprintf "#%02x%02x%02x" r g b

(** Linear interpolation between two values. *)
let lerp a b t =
  int_of_float (float_of_int a +. (float_of_int b -. float_of_int a) *. t)

(** Interpolate between two colors. *)
let interpolate c1 c2 t =
  { r = lerp c1.r c2.r t; g = lerp c1.g c2.g t; b = lerp c1.b c2.b t }

(** Generate a deterministic pseudo-random value from a string. *)
let hash_string s =
  let h = ref 0 in
  String.iter (fun c -> h := !h * 31 + Char.code c) s;
  abs !h

(** Hot color scheme: red-orange-yellow gradient with variation. *)
let hot name =
  let h = hash_string name in
  let v1 = float_of_int (h mod 40) /. 40.0 in  (* 0.0 to 1.0 *)
  let v2 = float_of_int ((h / 40) mod 40) /. 40.0 in
  (* Base: red (255, 0, 0) to yellow (255, 255, 0) *)
  let r = 200 + int_of_float (55.0 *. v1) in
  let g = 50 + int_of_float (200.0 *. v2) in
  let b = 0 in
  to_hex { r; g; b }

(** Cold color scheme: blue-cyan-green gradient. *)
let cold name =
  let h = hash_string name in
  let v1 = float_of_int (h mod 40) /. 40.0 in
  let v2 = float_of_int ((h / 40) mod 40) /. 40.0 in
  let r = 0 in
  let g = 100 + int_of_float (155.0 *. v1) in
  let b = 150 + int_of_float (105.0 *. v2) in
  to_hex { r; g; b }

(** Memory color scheme: green gradient. *)
let memory name =
  let h = hash_string name in
  let v1 = float_of_int (h mod 40) /. 40.0 in
  let v2 = float_of_int ((h / 40) mod 40) /. 40.0 in
  let r = 50 + int_of_float (100.0 *. v1) in
  let g = 180 + int_of_float (75.0 *. v2) in
  let b = 50 + int_of_float (100.0 *. v1) in
  to_hex { r; g; b }

(** IO color scheme: purple gradient. *)
let io name =
  let h = hash_string name in
  let v1 = float_of_int (h mod 40) /. 40.0 in
  let v2 = float_of_int ((h / 40) mod 40) /. 40.0 in
  let r = 150 + int_of_float (105.0 *. v1) in
  let g = 50 + int_of_float (100.0 *. v2) in
  let b = 180 + int_of_float (75.0 *. v1) in
  to_hex { r; g; b }
