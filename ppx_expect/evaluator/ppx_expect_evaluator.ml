open Base
open Stdio
open Expect_test_common.Std
open Expect_test_matcher.Std

module Test_result = Ppx_inline_test_lib.Runtime.Test_result
module Collector_test_outcome = Expect_test_collector.Test_outcome

type group =
  { filename      : File.Name.t
  ; file_contents : string
  ; tests         : Matcher.Test_outcome.t Map.M(File.Location).t
  }

let convert_collector_test  ~allow_output_patterns (test : Collector_test_outcome.t)
  : File.Location.t * Matcher.Test_outcome.t =
  let saved_output =
    Map.of_alist_multi (module File.Location) test.saved_output
    |> Map.map ~f:Matcher.Saved_output.of_nonempty_list_exn
  in
  let expectations =
    List.map test.expectations ~f:(fun (expect : Expectation.Raw.t) ->
      (expect.extid_location,
       Expectation.map_pretty expect
         ~f:(Lexer.parse_pretty ~allow_output_patterns)))
    |> Map.of_alist_exn (module File.Location)
  in
  (test.location,
   { expectations
   ; saved_output
   ; trailing_output = Matcher.Saved_output.of_nonempty_list_exn [test.trailing_output]
   ; upon_unreleasable_issue = test.upon_unreleasable_issue
   })
;;

let dir_seps = '/' :: if Sys.win32 then ['\\'; ':'] else []

let resolve_filename filename =
  let relative_to =
    match Ppx_inline_test_lib.Runtime.source_tree_root with
    | None -> File.initial_dir ()
    | Some root ->
      if Caml.Filename.is_relative root then
        let initial_dir = File.initial_dir () in
        (* Simplification for the common case where [root] is of the form [(../)*..] *)
        let l = String.split_on_chars root ~on:dir_seps in
        if List.for_all l ~f:(String.equal Caml.Filename.parent_dir_name) then
          List.fold_left l ~init:initial_dir ~f:(fun dir _ ->
            Caml.Filename.dirname dir)
        else
          Caml.Filename.concat initial_dir root
      else
        root
  in
  File.Name.relative_to ~dir:relative_to filename

let create_group ~allow_output_patterns (filename, tests) =
  let module D = File.Digest in
  let expected_digest =
    match
      List.map tests ~f:(fun (t : Collector_test_outcome.t) -> t.file_digest)
      |> List.dedup_and_sort ~compare:D.compare
    with
    | [digest] -> digest
    | [] -> assert false
    | digests ->
      Printf.ksprintf failwith
        !"Expect tests make inconsistent assumption about file \"%{File.Name}\" \
          %{sexp:D.t list}"
        filename digests
  in
  let file_contents =
    In_channel.read_all (resolve_filename filename)
  in
  let current_digest =
    Caml.Digest.string file_contents |> Caml.Digest.to_hex |> D.of_string
  in
  if D.compare expected_digest current_digest <> 0 then
    Printf.ksprintf failwith
      !"File \"%{File.Name}\" changed, you need rebuild inline_test_runner \
        to be able to run expect tests \
        (expected digest: %{D}, current digest: %{D})"
      filename expected_digest current_digest;
  let tests =
    List.map tests ~f:(convert_collector_test ~allow_output_patterns)
    |> Map.of_alist_reduce (module File.Location) ~f:Matcher.Test_outcome.merge_exn
  in
  { filename; file_contents; tests }
;;

let convert_collector_tests ~allow_output_patterns tests : group list =
  List.map tests ~f:(fun (test : Collector_test_outcome.t) ->
    (test.location.filename, test))
  |> Map.of_alist_multi (module File.Name)
  |> Map.to_alist
  |> List.map ~f:(create_group ~allow_output_patterns)
;;

let process_group ~use_color ~in_place ~diff_command ~allow_output_patterns
      { filename; file_contents; tests }
  : Test_result.t =
  let bad_outcomes =
    Map.fold tests ~init:[] ~f:(fun ~key:location ~data:test acc ->
      match
        Matcher.evaluate_test ~file_contents ~location test ~allow_output_patterns
      with
      | Match -> acc
      | Correction c -> c :: acc)
    |> List.rev
  in
  let filename = resolve_filename filename in
  let dot_corrected = filename ^ ".corrected" in
  let remove file =
    if Caml.Sys.file_exists file then Caml.Sys.remove file
  in
  match bad_outcomes with
  | [] ->
    remove dot_corrected;
    Success
  | _ ->
    let no_diff =
      match diff_command with
      | Some "-" -> true
      | None | Some _ -> false
    in
    let write_corrected ~file =
      Matcher.write_corrected bad_outcomes
        ~file
        ~file_contents
        ~mode:Inline_expect_test
    in
    match in_place with
    | true ->
      write_corrected ~file:filename;
      remove dot_corrected;
      Success
    | false ->
      match no_diff with
      | true ->
        write_corrected ~file:dot_corrected;
        Success
      | false ->
        let tmp_corrected =
          (* We need a temporary file for corrections to allow [Ppxlib_print_diff] to work when
             multiple inline_tests_runner are run simultaneously. Otherwise one copy may
             remove the corrected file before the other can print the diff. *)
          Caml.Filename.temp_file (Caml.Filename.basename filename) ".tmp_corrected"
            ~temp_dir:(Caml.Filename.dirname filename)
        in
        write_corrected ~file:tmp_corrected;
        Ppxlib_print_diff.print ~file1:filename ~file2:tmp_corrected ~use_color ?diff_command ();
        Caml.Sys.rename tmp_corrected dot_corrected;
        Failure
;;

let evaluate_tests ~use_color ~in_place ~diff_command ~allow_output_patterns =
  convert_collector_tests (Expect_test_collector.tests_run ())
    ~allow_output_patterns
  |> List.map ~f:(process_group ~use_color ~in_place ~diff_command ~allow_output_patterns)
  |> Test_result.combine_all
;;

let () =
  Ppx_inline_test_lib.Runtime.add_evaluator ~f:(fun () ->
    evaluate_tests
      ~use_color:Ppx_inline_test_lib.Runtime.use_color
      ~in_place:Ppx_inline_test_lib.Runtime.in_place
      ~diff_command:Ppx_inline_test_lib.Runtime.diff_command
      ~allow_output_patterns:Ppx_inline_test_lib.Runtime.allow_output_patterns)
;;
