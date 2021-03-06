open! Core_kernel
open! Import
open! String

(*TEST = slice "hey" 0 0 = ""*) (* This is what I would expect *)
let%test _ = slice "hey" 0 0 = "hey" (* But this is what we get! *)

let%test _ = slice "hey" 0 1 = "h"
let%test _ = slice "hey" 0 2 = "he"
let%test _ = slice "hey" 0 3 = "hey"
let%test _ = slice "hey" 1 1 = ""
let%test _ = slice "hey" 1 2 = "e"
let%test _ = slice "hey" 1 3 = "ey"
let%test _ = slice "hey" 2 2 = ""
let%test _ = slice "hey" 2 3 = "y"
let%test _ = slice "hey" 3 3 = ""

let%test_module "Caseless Comparable" =
  (module struct
    let%test _ =
      Int.equal (Base.Map.find_exn (Caseless.Map.of_alist_exn [("a", 4); ("b", 5)]) "A") 4

    let%test _ = Base.Set.mem (Caseless.Set.of_list ["hello"; "world"]) "heLLO"
    let%test _ = Int.equal (Base.Set.length (Caseless.Set.of_list ["a"; "A"])) 1

  end)

let%test_module "Caseless Hash" =
  (module struct
    let%test _ = Int.equal (Caseless.hash "Hello") (Caseless.hash "HELLO")
  end)

let%test_module "take_while" =
  (module struct
    let f = Char.is_digit

    let%test_unit _ = [%test_result: t] ( take_while "123abc456" ~f) ~expect:"123"
    let%test_unit _ = [%test_result: t] (rtake_while "123abc456" ~f) ~expect:"456"
    let%test_unit _ = [%test_result: t] ( take_while "123456"    ~f) ~expect:"123456"
    let%test_unit _ = [%test_result: t] (rtake_while "123456"    ~f) ~expect:"123456"
  end)
;;
