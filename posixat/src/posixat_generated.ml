(* This file was generated by: gen/gen.exe ml *)

open Types

external openat
  :  dir:Fd.t
  -> path:string
  -> flags:Open_flag.t list
  -> perm:File_perm.t
  -> Fd.t
  = "shexp_openat"

external faccessat
  :  dir:Fd.t
  -> path:string
  -> mode:Access_permission.t list
  -> flags:At_flag.t list
  -> unit
  = "shexp_faccessat"

external fchmodat
  :  dir:Fd.t
  -> path:string
  -> perm:File_perm.t
  -> flags:At_flag.t list
  -> unit
  = "shexp_fchmodat"

external fchownat
  :  dir:Fd.t
  -> path:string
  -> uid:int
  -> gid:int
  -> flags:At_flag.t list
  -> unit
  = "shexp_fchownat"

external mkdirat
  :  dir:Fd.t
  -> path:string
  -> perm:File_perm.t
  -> unit
  = "shexp_mkdirat"

external unlinkat
  :  dir:Fd.t
  -> path:string
  -> flags:At_flag.t list
  -> unit
  = "shexp_unlinkat"

external mkfifoat
  :  dir:Fd.t
  -> path:string
  -> perm:File_perm.t
  -> unit
  = "shexp_mkfifoat"

external linkat
  :  olddir:Fd.t
  -> oldpath:string
  -> newdir:Fd.t
  -> newpath:string
  -> flags:At_flag.t list
  -> unit
  = "shexp_linkat"

external renameat
  :  olddir:Fd.t
  -> oldpath:string
  -> newdir:Fd.t
  -> newpath:string
  -> unit
  = "shexp_renameat"

external symlinkat
  :  oldpath:string
  -> newdir:Fd.t
  -> newpath:string
  -> unit
  = "shexp_symlinkat"

external has_openat : unit -> bool = "shexp_has_openat"
let has_openat = has_openat ()

external has_faccessat : unit -> bool = "shexp_has_faccessat"
let has_faccessat = has_faccessat ()

external has_fchmodat : unit -> bool = "shexp_has_fchmodat"
let has_fchmodat = has_fchmodat ()

external has_fchownat : unit -> bool = "shexp_has_fchownat"
let has_fchownat = has_fchownat ()

external has_mkdirat : unit -> bool = "shexp_has_mkdirat"
let has_mkdirat = has_mkdirat ()

external has_unlinkat : unit -> bool = "shexp_has_unlinkat"
let has_unlinkat = has_unlinkat ()

external has_mkfifoat : unit -> bool = "shexp_has_mkfifoat"
let has_mkfifoat = has_mkfifoat ()

external has_linkat : unit -> bool = "shexp_has_linkat"
let has_linkat = has_linkat ()

external has_renameat : unit -> bool = "shexp_has_renameat"
let has_renameat = has_renameat ()

external has_symlinkat : unit -> bool = "shexp_has_symlinkat"
let has_symlinkat = has_symlinkat ()
