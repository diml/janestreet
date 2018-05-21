open! Core
open Email_message

module type With_headers = Envelope_container_intf.With_headers
module type With_info = Envelope_container_intf.With_info with type envelope_info := Envelope_info.t

module Make_with_headers(S : sig
    type t

    val headers     : t -> Email_headers.t
    val set_headers : t -> Email_headers.t -> t
  end) = struct
  include S

  let last_header ?whitespace t name =
    Email_headers.last ?whitespace (headers t) name
  ;;

  let find_all_headers ?whitespace t name =
    Email_headers.find_all ?whitespace (headers t) name
  ;;

  let modify_headers t ~f =
    let headers = headers t in
    set_headers t (f headers)
  ;;

  let add_header ?whitespace t ~name ~value =
    modify_headers t ~f:(fun headers ->
      Email_headers.add ?whitespace headers ~name ~value)
  ;;

  let add_headers ?whitespace t ts =
    modify_headers t ~f:(fun headers ->
      Email_headers.add_all ?whitespace headers ts)
  ;;

  let set_header ?whitespace t ~name ~value =
    modify_headers t ~f:(fun headers ->
      Email_headers.set ?whitespace headers ~name ~value)
  ;;

  let add_header_at_bottom ?whitespace t ~name ~value =
    modify_headers t ~f:(fun headers ->
      Email_headers.add_at_bottom ?whitespace headers ~name ~value)
  ;;

  let add_headers_at_bottom ?whitespace t ts =
    modify_headers t ~f:(fun headers ->
      Email_headers.add_all_at_bottom ?whitespace headers ts)
  ;;

  let set_header_at_bottom ?whitespace t ~name ~value =
    modify_headers t ~f:(fun headers ->
      Email_headers.set_at_bottom ?whitespace headers ~name ~value)
  ;;

  let filter_headers ?whitespace t ~f =
    modify_headers t ~f:(fun headers ->
      Email_headers.filter ?whitespace headers ~f)
  ;;

  let map_headers ?whitespace t ~f =
    modify_headers t ~f:(fun headers ->
      Email_headers.map ?whitespace headers ~f)
  ;;

  let smash_and_add_header ?whitespace t ~name ~value =
    modify_headers t ~f:(fun headers ->
      Email_headers.smash_and_add ?whitespace headers ~name ~value)
  ;;
end

module Make_with_info(S : sig
    type t

    val info : t -> Envelope_info.t
  end) = struct

  include S

  let sender              t = Envelope_info.sender              (info t)
  let sender_args         t = Envelope_info.sender_args         (info t)
  let string_sender       t = Envelope_info.string_sender       (info t)
  let recipients          t = Envelope_info.recipients          (info t)
  let rejected_recipients t = Envelope_info.rejected_recipients (info t)
  let string_recipients   t = Envelope_info.string_recipients   (info t)
  let route               t = Envelope_info.route               (info t)
  let id                  t = Envelope_info.id                  (info t)
end
