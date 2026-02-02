(** SVG rendering for flamegraphs.

    This module provides functions to render flamegraphs as interactive SVG
    images with zoom, pan, and search functionality. *)

(** {1 Configuration} *)

(** Color scheme for coloring frames. *)
type color_scheme =
  | Hot  (** Red-orange-yellow gradient, suitable for CPU profiles. *)
  | Cold  (** Blue-cyan gradient, suitable for off-CPU or IO profiles. *)
  | Memory  (** Green gradient, suitable for memory allocation profiles. *)
  | Io  (** Purple gradient, suitable for IO profiles. *)
  | Custom of (Flamegraph.frame -> depth:int -> string)
      (** User-provided function returning a CSS color string. Receives the
          frame and its depth in the stack (0 = root). *)

type config = {
  width : int;  (** SVG width in pixels. Default: [1200]. *)
  row_height : int;  (** Height of each frame row in pixels. Default: [16]. *)
  font_size : int;  (** Font size in pixels. Default: [12]. *)
  font_family : string;  (** Font family. Default: ["monospace"]. *)
  min_width_for_text : float;
      (** Minimum frame width ratio (0.0-1.0) to display text. Default: [0.02].
      *)
  color_scheme : color_scheme;  (** Color scheme for frames. Default: [Hot]. *)
  title : string option;
      (** Optional title displayed at the top. Default: [None]. *)
  background : string;  (** Background color. Default: ["#f8f8f8"]. *)
}
(** SVG rendering configuration. *)

val default_config : config
(** Default configuration with sensible values. *)

val config :
  ?width:int ->
  ?row_height:int ->
  ?font_size:int ->
  ?font_family:string ->
  ?min_width_for_text:float ->
  ?color_scheme:color_scheme ->
  ?title:string ->
  ?background:string ->
  unit ->
  config
(** Create a configuration with optional overrides.

    Example:
    {[
      let cfg = Svg.config ~width:1600 ~title:"My Profile" ()
    ]} *)

(** {1 Rendering} *)

val to_string : ?config:config -> Flamegraph.t -> string
(** [to_string ?config fg] renders the flamegraph to an SVG string.

    The resulting SVG includes interactive JavaScript for:
    - Click to zoom into a frame
    - Right-click or click "Reset Zoom" to reset
    - Search box to highlight matching frames
    - Hover tooltips showing frame details *)

val to_channel : ?config:config -> out_channel -> Flamegraph.t -> unit
(** [to_channel ?config oc fg] writes the SVG to an output channel. *)

val to_file : ?config:config -> string -> Flamegraph.t -> (unit, string) result
(** [to_file ?config path fg] writes the SVG to a file. Returns [Error msg] if
    the file cannot be written. *)
