
(* TYPES *)

type register = string

type rvalue =
  | Register of register
  | Int of int

type instruction =
  | Set of register * rvalue
  | Sub of register * rvalue
  | Mul of register * rvalue
  | Jump of rvalue * rvalue


(* REGISTERS *)

module Register: sig
  include Map.S with type key = string
  val find_default: default:'a -> key -> 'a t -> 'a
end = struct
  include Map.Make(String)
  let find_default ~default key table =
    match find_opt key table with
    | None -> default
    | Some value -> value
end


(* DUET *)

let get_register_value context register =
  Register.find_default ~default:0 register context

let eval_rvalue context rvalue =
  match rvalue with
  | Int i -> i
  | Register register -> get_register_value context register

let eval_operation context op register rvalue =
  let register_value = get_register_value context register in
  let rvalue_value = eval_rvalue context rvalue in
  Register.add register (op register_value rvalue_value) context

let do_duet instructions =
  let length = Array.length instructions in
  let rec aux_duet ~count context index =
    if index >= length || index < 0 then
      count
    else
      match instructions.(index) with
      | Set (register, rvalue) ->
        let rvalue = eval_rvalue context rvalue in
        let context' = Register.add register rvalue context in
        aux_duet ~count context' (succ index)
      | Sub (register, rvalue) ->
        let context' = eval_operation context ( - ) register rvalue in
        aux_duet ~count context' (succ index)
      | Mul (register, rvalue) ->
        let context' = eval_operation context ( * ) register rvalue in
        aux_duet ~count:(succ count) context' (succ index)
      | Jump (register, rvalue) ->
        let register_value = eval_rvalue context register in
        let index =
          if register_value <> 0 then index + (eval_rvalue context rvalue)
          else succ index
        in
        aux_duet ~count context index
  in
  aux_duet ~count:0 Register.empty 0

(* INPUT *)

let with_channel filename fn =
  let channel = open_in filename in
  try
    let result = fn channel in
    close_in channel;
    result
  with exn ->
    close_in channel;
    raise exn

let parse_instruction line =
  let parse_rvalue rvalue =
    try Int (int_of_string rvalue)
    with Failure _ -> Register rvalue
  in
  match String.split_on_char ' ' line with
  | [ "set"; register; rvalue ] ->
    Set (register, parse_rvalue rvalue)
  | [ "sub"; register; rvalue ] ->
    Sub (register, parse_rvalue rvalue)
  | [ "mul"; register; rvalue ] ->
    Mul (register, parse_rvalue rvalue)
  | [ "jnz"; rvalue; rvalue' ] ->
    Jump (parse_rvalue rvalue, parse_rvalue rvalue')
  | _ ->
    failwith ("Unknonw instruction: " ^ line)

let parse_instructions channel =
  let rec aux_parse acc =
    try
      let line = input_line channel in
      let instruction = parse_instruction line in
      aux_parse (instruction :: acc)
    with End_of_file ->
      List.rev acc
  in
  let result = aux_parse [] in
  Array.of_list result

let () =
  let instructions = with_channel "input" parse_instructions in
  let result = do_duet instructions in
  Format.printf "%d@." result
