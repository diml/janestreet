module Stable = struct
  open! Core.Core_stable
  open! Import_stable

  (* The intent is to keep only the latest used type.  If the types have changed, we just
     regenerate the hgrc file and override it with the new syntax. *)

  module Feature = struct
    module V2 = struct
      type t =
        { feature_id   : Feature_id.V1.t
        ; feature_path : Feature_path.V1.t
        }
      [@@deriving compare, sexp]

      let t_of_sexp sexp = Core.Sexp.of_sexp_allow_extra_fields t_of_sexp sexp
    end

    module Model = V2
  end

  module Kind = struct
    module V2 = struct
      type t =
        [ `Feature of Feature.V2.t
        | `Satellite_repo
        | `Clone
        | `Fake_for_testing
        ]
      [@@deriving compare, sexp]
    end

    module Model = V2
  end

  module Info = struct
    module V2 = struct
      type t =
        { generated_by     : string
        ; remote_repo_path : Remote_repo_path.V1.t
        ; kind             : Kind.V2.t
        }
      [@@deriving compare, sexp]

      let t_of_sexp sexp = Core.Sexp.of_sexp_allow_extra_fields t_of_sexp sexp
    end

    module Model = V2
  end
end

open! Core
open! Async
open! Import

module Commented_sexp : sig
  val to_commented_string_hum : Sexp.t -> string

  (** Parse the first block of commented lines that are consecutive *)
  val of_commented_string_hum : string -> Sexp.t
end = struct

  let prefix = "#"

  let to_commented_string_hum sexp =
    sexp
    |> Sexp.to_string_hum
    |> String.split_lines
    |> List.map ~f:(fun s -> prefix ^ " " ^ s)
    |> String.concat ~sep:"\n"
  ;;

  let of_commented_string_hum string =
    string
    |> String.split_lines
    |> List.map ~f:(fun s -> String.chop_prefix s ~prefix)
    |> List.drop_while ~f:Option.is_none
    |> List.take_while ~f:Option.is_some
    |> List.filter_opt
    |> String.concat ~sep:"\n"
    |> Sexp.of_string
  ;;

  let%test_module "comments" =
    (module struct
      type t =
        { a : int
        ; b : string
        ; c : float
        }
      [@@deriving compare, sexp]

      let example_value = { a = 42; b = "hello-string"; c = 42. }

      let example_string = "\
Some ignored line
# ((a 42)
#  (b hello-string)
#  (c 42.))
Some other ignored line
# other commented block to be ignored
"
      ;;

      let%test_unit "read" =
        [%test_result: t]
          (of_commented_string_hum example_string |> [%of_sexp: t])
          ~expect:example_value
      ;;

      let assert_all_lines_are_commented s =
        List.iter (String.split_lines s) ~f:(fun line ->
          assert (Option.is_some (String.chop_prefix line ~prefix)));
      ;;

      let%test_unit "write" =
        [%test_result: t]
          (example_value
           |> [%sexp_of: t]
           |> to_commented_string_hum
           |> (fun s -> assert_all_lines_are_commented s; s)
           |> of_commented_string_hum
           |> [%of_sexp: t])
          ~expect:example_value
      ;;
    end)
end

module Feature = Stable.Feature.Model
module Kind    = Stable.Kind.Model
module Info    = Stable.Info.Model

type t =
  { repo_root        : Repo_root.t
  ; remote_repo_path : Remote_repo_path.t
  ; kind             : Kind.t
  }
[@@deriving compare, sexp_of]

let hgrc repo_root =
  Abspath.to_string (Repo_root.append repo_root (Path_in_repo.of_string ".hg/hgrc"))
;;

let extract_info repo_root =
  let file = hgrc repo_root in
  Monitor.try_with_or_error ~extract_exn:true (fun () ->
    let%map contents = Reader.file_contents file in
    Commented_sexp.of_commented_string_hum contents
    |> [%of_sexp: Info.t])
;;

let info_of_t t =
  { Info.
    generated_by     = Version_util.version
  ; remote_repo_path = t.remote_repo_path
  ; kind             = t.kind
  }
;;

let t_of_info repo_root (info : Info.t) =
  { repo_root
  ; remote_repo_path = info.remote_repo_path
  ; kind             = info.kind
  }
;;

let%test_unit "info" =
  let repo_root = Repo_root.of_abspath (Abspath.of_string "/dev/null") in
  let t =
    { repo_root
    ; remote_repo_path = Remote_repo_path.null
    ; kind =  `Fake_for_testing
    }
  in
  [%test_result: t] ~expect:t (t_of_info repo_root (info_of_t t))
;;

let save t =
  let info = info_of_t t in
  Writer.with_file_atomic (hgrc t.repo_root) ~f:(fun w ->
    let remote_repo_path = Remote_repo_path.to_string t.remote_repo_path in
    List.iter ~f:(Writer.write_line w)
      [ "# ; THIS FILE IS GENERATED BY IRON.  DO NOT EDIT MANUALLY"
      ; "#"
      ; Commented_sexp.to_commented_string_hum (Info.sexp_of_t info)
      ; ""
      ; "%include /j/office/app/fe/prod/etc/workspaces.hgrc"
      ; ""
      ; "[paths]"
      ; "default = " ^ remote_repo_path
      ];
    (match t.kind with
     | `Clone | `Satellite_repo | `Fake_for_testing -> ()
     | `Feature { feature_path; feature_id = _ } ->
       let feature = Feature_path.to_string feature_path in
       Writer.newline w;
       List.iter ~f:(Writer.write_line w)
         [ "[defaults]"
         ; "incoming = -r " ^ feature
         ; "outgoing = -r " ^ feature
         ; "pull     = -r " ^ feature
         ; "# The remote repo path is specified explicitly here to prevent pushing"
         ; "# to other repos.  If you push to some other repo without pushing to"
         ; "# the remote repo specified here, fe's unclean workspaces check may miss"
         ; "# those changesets."
         ; "push     = -r " ^ feature ^ " " ^ remote_repo_path
         ]);
    Deferred.unit
  )
;;

let default_line_regex =
  Regex.create_exn "^[ ]*default[ ]+=[ ]+(ssh://hg//hg/.*)$"
;;

let match_default_line line =
  match Regex.find_first ~sub:(`Index 1) default_line_regex line with
  | Error _ -> None
  | Ok remote_repo_path ->
    Option.try_with (fun () ->
      Remote_repo_path.of_string remote_repo_path
      |> Remote_repo_path.family
      |> Option.map ~f:Feature_name.of_string)
    |> Option.join
;;

let%test_unit _ =
  List.iter ~f:(fun (line, expected) ->
    [%test_result: Feature_name.t option]
      ~expect:(Option.map ~f:Feature_name.of_string expected)
      (match_default_line line))
    [ "default = ssh://hg//hg/jane/submissions"          , Some "jane"
    ; "  default   =  ssh://hg//hg/scaffoo/submissions " , Some "scaffoo"
    ; "default = ssh://jdoe@blah//some/random/path/blah" , None
    ]
;;

let extract_root_feature_from_hgrc repo_root =
  let file = hgrc repo_root in
  let%map res =
    Monitor.try_with_join_or_error ~extract_exn:true (fun () ->
      let%map lines = Reader.file_lines file in
      match List.find_map lines ~f:match_default_line with
      | Some feature_name -> Ok feature_name
      | None ->
        error_s
          [%sexp
            "Could not extract a root feature from this .hg/hgrc file",
            { file  = (file : string)
            ; regex = (Regex.pattern default_line_regex : string)
            ; hgrc  = (lines : string list)
            }
          ])
  in
  if Verbose.workspaces
  then Debug.ams [%here] "Workspace_hgrc.extract_root_feature_from_hgrc"
         res [%sexp_of: Feature_name.t Or_error.t];
  res
;;
