open Core_kernel
open Async_kernel
open Incr_dom
open Js_of_ocaml
open Vdom

module Exn_location = struct
  type t =
    | None
    | Visibility
    | Action
    | Stabilization1
    | Stabilization2
    | Startup
    | On_display
    | On_keydown (* Exception in event handler does NOT cause the incr_dom app to stop *)
  [@@deriving sexp, compare, enumerate]

  let to_string t = sexp_of_t t |> Sexp.to_string_hum
  let of_string s =
    match Sexp.of_string s |> t_of_sexp with
    | t -> Some t
    | exception _ -> None
end

module Model = struct
  type mode = M1 | M2 [@@deriving compare]
  type t = { mode         : mode
           ; exn_location : Exn_location.t
           ; monitor      : Monitor.t
           ; stop         : unit Ivar.t
           }
  [@@deriving fields]

  let cutoff t1 t2 = compare t1 t2 = 0
end

module Action = struct
  type t =
    | Switch
    | Set_exn_location of Exn_location.t
    | Stop
  [@@deriving sexp]

  let should_log _ = true
end

module State = struct
  type t = unit
end

let fail_if_equal loc1 loc2 =
  if Exn_location.compare loc1 loc2 = 0
  then (failwithf !"Failed on %{sexp:Exn_location.t}" loc1 ())

let maybe_fail (m:Model.t) loc =
  fail_if_equal m.exn_location loc

let apply_action (action:Action.t) (m:Model.t) _state =
  maybe_fail m Action;
  match action with
  | Set_exn_location exn_location ->
    { m with exn_location }
  | Switch ->
    begin match m.mode with
    | M1 -> { m with mode = M2 }
    | M2 -> { m with mode = M1 }
    end
  | Stop ->
    Ivar.fill_if_empty m.stop ();
    m

let update_visibility m =
  maybe_fail m Visibility;
  m

let key_handler (m:Model.t) ~(inject : Action.t -> Vdom.Event.t) =
  Attr.on_keydown (fun ev ->
    Async_kernel_scheduler.within_v ~monitor:m.monitor (fun () ->
      maybe_fail m On_keydown;
      match Dom_html.Keyboard_code.of_event ev with
      | KeyS -> inject Switch
      | KeyX -> inject Stop
      | _    -> Vdom.Event.Ignore
    )
    |> Option.value ~default:Vdom.Event.Ignore
  )

let view (m:Model.t Incr.t) ~(inject : Action.t -> Vdom.Event.t) =
  let open Incr.Let_syntax in
  let set_location =
    let open Js_of_ocaml in
    Vdom.Attr.on_change (fun (_ : Dom_html.event Js.t) value ->
      match Exn_location.of_string value with
      | Some loc -> inject (Set_exn_location loc)
      | None -> Vdom.Event.Ignore)
  in
  let%map m = m in
  let attr = [ key_handler m ~inject ] in
  let text =
    match m.mode with
    | M1 ->
      maybe_fail m Stabilization1;
      Node.text "Model 1"
    | M2 ->
      maybe_fail m Stabilization2;
      Node.text "Model 2"
  in
  Node.body attr
    [ Node.div [Attr.on_click (fun _ -> inject Switch)] [text]
    ; Node.select [set_location]
        (List.map Exn_location.all ~f:(fun loc ->
           let s = Exn_location.to_string loc in
           let selected =
             if [%compare.equal: Exn_location.t] m.exn_location loc
             then [Attr.create "selected" "selected"]
             else []
           in
           Node.option
             (selected @ [ Attr.value s ])
             [ Node.text s ]))
    ]

let on_startup ~schedule:_ model =
  maybe_fail model Startup;
  Deferred.return ()

let on_display ~old:_ (m:Model.t) _state =
  maybe_fail m On_display;
  ()

let init ?init_loc monitor ~stop : Model.t =
  let exn_location =
    match init_loc with
    | None     -> Exn_location.None
    | Some loc ->
      match Exn_location.of_string loc with
      | Some x -> x
      | None   -> Exn_location.Startup
  in
  { mode = M1; exn_location; monitor; stop }
