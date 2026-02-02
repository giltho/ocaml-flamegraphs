(** Folded stacks format (compatible with flamegraph.pl).

    This module provides import and export functionality for the folded stacks
    format used by Brendan Gregg's flamegraph.pl tool.

    The format is: [frame1;frame2;frame3 weight\n]

    Example:
    {[
      main;
      process;
      compute 150.5 main;
      process;
      allocate 42.0 main;
      init 30.0
    ]} *)

(** {1 Configuration} *)

(** How to format weights in output. *)
type weight_format =
  | Integer  (** Round weights to integers. *)
  | Float of int  (** Float with specified decimal places. *)

type config = {
  separator : string;  (** Frame separator. Default: [";"] *)
  weight_format : weight_format;
      (** How to format weights. Default: [Float 2] *)
}
(** Export/import configuration. *)

val default_config : config
(** Default configuration. *)

val config : ?separator:string -> ?weight_format:weight_format -> unit -> config
(** Create a configuration with optional overrides. *)

(** {1 Export} *)

val to_string : ?config:config -> Flamegraph.t -> string
(** [to_string ?config fg] exports the flamegraph to folded stacks format. *)

val to_channel : ?config:config -> out_channel -> Flamegraph.t -> unit
(** [to_channel ?config oc fg] writes folded stacks to an output channel. *)

val to_file : ?config:config -> string -> Flamegraph.t -> (unit, string) result
(** [to_file ?config path fg] writes folded stacks to a file. Returns
    [Error msg] if the file cannot be written. *)

(** {1 Import} *)

val of_string : ?config:config -> string -> (Flamegraph.t, string) result
(** [of_string ?config s] parses folded stacks format into a flamegraph. Returns
    [Error msg] if parsing fails. *)

val of_channel : ?config:config -> in_channel -> (Flamegraph.t, string) result
(** [of_channel ?config ic] reads and parses from an input channel. *)

val of_file : ?config:config -> string -> (Flamegraph.t, string) result
(** [of_file ?config path] reads and parses from a file. *)
