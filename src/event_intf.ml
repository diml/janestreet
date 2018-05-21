(** The event type used for creating virtual-dom callbacks.

    The various kinds of handlers are registered by users of virtual dom, and allow them
    to pick up events that are scheduled by other users, without these use-cases
    interfering with each other.
*)

open Js_of_ocaml

module type Handler = sig
  module Action : sig
    type t
  end

  val handle : Action.t -> unit
end

module type Visibility_handler = sig
  val handle : unit -> unit
end

module type S = sig
  type action

  type t = ..
  type t += C : action -> t

  val inject : action -> t
end

module type Event = sig

  type t = ..
  type t +=
    (** [Ignore] events are dropped, so no handler is called *)
    | Ignore
    (** [Viewport_changed] events are delivered to all visibility handlers  *)
    | Viewport_changed
    (** [Stop_propagation] prevents the underlying DOM event from propagating up to the
        parent elements *)
    | Stop_propagation
    (** [Prevent_default] prevents the default browser action from occurring as a result
        of this event *)
    | Prevent_default
    (** Allows one to represent a list of handlers, which will be individually dispatched
        to their respective handlers. This is so callbacks can return multiple events of
        whatever kind. *)
    | Many of t list

  module type Handler = Handler
  module type Visibility_handler = Visibility_handler
  module type S = S

  (** For registering a new handler and a corresponding new constructor of the Event.t
      type *)
  module Define (Handler : Handler)
    : S with type action := Handler.Action.t
         and type t := t

  (** For registering a handler for Viewport_changed events. Note that if this functor is
      called multiple times, each handler will see all of the events. *)
  module Define_visibility (VH : Visibility_handler) : sig end

  module Expert : sig
    (** [handle t] looks up the [Handler.handle] function in the table of [Define]d
        functions, unwraps the [Event.t] back into its underlying [Action.t], and applies
        the two.  This is only intended for internal use by this library, specifically by
        the attribute code. *)
    val handle : #Dom_html.event Js.t -> t -> unit

    (** [handle_non_dom_event_exn] is the same as [handle] except that it raises in any
        case that would have required the [#Dom_html.event Js.t]. In particular, this
        can be to feed Actions back to the system that are not triggered by events from
        the DOM and do not have a corresponding [#Dom_html.event Js.t]. *)
    val handle_non_dom_event_exn : t -> unit
  end

end
