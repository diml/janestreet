open! Core_kernel
open! Import
open! Rope

let%test _ = is_empty empty
let%test _ = not (is_empty (of_string "non-empty"))

(* Note that it's possible to hit the length restriction while only using logarithmic
   amounts of memory. *)
let%test "length overflow" =
  let x = of_string "x" in
  Exn.does_raise (fun () -> Fn.apply_n_times ~n:Int.num_bits (fun x -> x ^ x) x)

let%test_unit _ =
  [%test_result: string] ~expect:""
    (concat ~sep:(of_string ", ") []
     |> to_string);
  [%test_result: string] ~expect:"one, two, three"
    (concat ~sep:(of_string ", ") [of_string "one"; of_string "two"; of_string "three"]
     |> to_string)

let%test_unit _ =
  let r = (of_string "abc" ^ of_string "def") ^ (of_string "ghi" ^ of_string "jkl") in
  let buffer = Buffer.create 12 in
  add_to_buffer r buffer;
  [%test_result: String.t] ~expect:"abcdefghijkl" (Buffer.contents buffer)
;;

let%test_unit "no stack overflow" =
  [%test_result: string]
    (to_string (
       List.fold_left ~init:(of_string "") ~f:(^) (
         List.init 1000000 ~f:(fun _x -> of_string "x"))))
    ~expect:(String.make 1000000 'x')
;;

let%test_unit _ = [%test_result: string] (to_string (of_string "")) ~expect:""
let%test_unit _ = [%test_result: string] (to_string (of_string "x")) ~expect:"x"
let%test_unit _ = [%test_result: string]
                    (to_string (of_string "ab" ^ of_string "cd" ^ of_string "efg"))
                    ~expect:"abcdefg"
let%test_unit _ =
  let rec go = function
    | 0 -> of_string "0"
    | n -> go (n - 1) ^ of_string (string_of_int n) ^ go (n - 1)
  in
  [%test_result: string]
    (to_string (go 4))
    ~expect:"0102010301020104010201030102010"
;;

