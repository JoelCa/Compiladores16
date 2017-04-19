structure tigercodegen :> tigercodegen =
struct

structure A = tigerassem
structure T = tigertree

open tigerframe
         
fun codegen (frame) (stm) =
  let val ilist = ref (nil : A.instr list)
      fun emit x = ilist := x :: !ilist
      fun result (gen) = let val t = tigertemp.newtemp() in gen t; t end
      fun muchArgAux [] = []
        | muchArgAux (T.TEMP t :: xs) = t :: muchArgAux xs
        | muchArgAux (_ :: xs) = muchArgAux xs
      fun munchStm (T.SEQ (a,b)) = (munchStm a; munchStm b)
        | munchStm (T.MOVE (T.MEM (T.BINOP (T.PLUS, e1, T.CONST i)), e2)) = emit (A.OPER { assem = "str 's0, ['s1,'s2]\n",
                                                                                           src = [munchExp e2, munchExp e1, munchExp (T.CONST i)],
                                                                                           dst = [],
                                                                                           jump = NONE } )
        | munchStm (T.MOVE (T.MEM (T.BINOP (T.PLUS, T.CONST i, e1)), e2)) = emit (A.OPER { assem = "str 's0, ['s1,'s2]\n",
                                                                                           src = [munchExp e2, munchExp e1, munchExp (T.CONST i)],
                                                                                           dst = [],
                                                                                           jump = NONE } )
        | munchStm (T.MOVE (T.MEM e1, T.NAME l)) = emit (A.OPER { assem = "ldr 's0, =" ^ l ^ "\n",
                                                                  src = [munchExp e1],
                                                                  dst = [],
                                                                  jump = NONE })
        | munchStm (T.MOVE (T.MEM e1, e2)) = emit (A.OPER { assem = "str 's0, ['s1]\n",
                                                            src = [munchExp e2, munchExp e1],
                                                            dst = [],
                                                            jump = NONE })
        | munchStm (T.MOVE (T.TEMP i, e2)) = emit (A.MOVE { assem = "mov 's0, 's1\n",
                                                            src = [i, munchExp e2],
                                                            dst = [] })

        | munchStm (T.CJUMP (oper, e1, e2, t, _)) = let fun toAssemOper operacion = 
                                                          case operacion of
                                                              T.EQ  => "eq"
                                                            | T.NE  => "ne"
                                                            | T.LT  => "lt"
                                                            | T.GT  => "gt"
                                                            | T.LE  => "le"
                                                            | T.GE  => "ge"
                                                            | T.ULT => "lo"
                                                            | T.ULE => "ls"
                                                            | T.UGT => "hi"
                                                            | T.UGE => "hs"
                                                    in emit (A.OPER { assem = "cmp 's0 's1\n" ^ "b" ^ toAssemOper(oper) ^ " " ^ t ^"\n",
                                                                      src = [munchExp e1, munchExp e2],
                                                                      dst = [],
                                                                      jump = SOME [t] })
                                                    end
        | munchStm (T.JUMP (T.NAME s, _)) = emit (A.OPER { assem = "b " ^ s ^ "\n",
                                                           src = [],
                                                           dst = [],
                                                           jump = SOME [s]})
        | munchStm (T.LABEL lab) =  emit (A.LABEL { assem = lab^":\n",
                                                    lab = lab} )
        | munchStm (T.EXP (T.CALL (T.NAME name,args))) = emit (A.OPER { assem = "bl " ^ name ^ "\n",
                                                                        src = munchArgs (0,args),
                                                                        dst = calldefs,
                                                                        jump = SOME [name]})
        | munchStm (T.EXP e) = emit (A.OPER { assem = "",
                                              src = [munchExp e],
                                              dst = [],
                                              jump = NONE})
        | munchStm _ = raise Fail "No debería llegar! (munchStm)"

      and munchExp (T.MEM (T.BINOP (T.PLUS, e1, T.CONST i))) = result (fn r => emit (A.OPER { assem = "ldr 'd0, ['s0,'s1]\n",
                                                                                              src = [munchExp e1, munchExp (T.CONST i)],
                                                                                              dst = [r],
                                                                                              jump = NONE }))
        | munchExp (T.MEM (T.BINOP (T.PLUS, T.CONST i, e1))) = result (fn r => emit (A.OPER { assem = "ldr 'd0, ['s0,'s1]\n",
                                                                                              src = [munchExp e1, munchExp (T.CONST i)],
                                                                                              dst = [r],
                                                                                              jump = NONE }))
        | munchExp (T.MEM (T.CONST i)) = result (fn r => emit (A.OPER { assem = "ldr 'd0, ['s0]\n",
                                                                        src = [munchExp (T.CONST i)],
                                                                        dst = [r],
                                                                        jump = NONE }))
        | munchExp (T.MEM e1) = result (fn r => emit (A.OPER { assem = "ldr 'd0, ['s0]\n",
                                                               src = [munchExp e1],
                                                               dst = [r],
                                                               jump = NONE }))
        | munchExp (T.BINOP (oper, e1, e2)) = let fun toAssemOper operation =
                                                    case operation of
                                                        T.PLUS  => "add"
                                                      | T.MINUS => "sub"
                                                      | T.MUL   => "mul"
                                                      | T.DIV   => "sdiv"
                                                      | T.AND   => "and"
                                                      | T.OR    => "orr"
                                                      | T.XOR   => "eor"
                                                      | _       => raise Fail "No debería pasar! (munchExp1)\n"
                                                  fun assemCode operation = 
                                                    case operation of
                                                        T.LSHIFT   => "mov 'd0, 's0, lsl 's1\n"
                                                      | T.RSHIFT   => "mov 'd0, 's0, lsr 's1\n"
                                                      | T.ARSHIFT  => "mov 'd0, 's0, asr 's1\n"
                                                      | oper  => toAssemOper(oper) ^ " 'd0, 's0, 's1\n"
                                              in result (fn r => emit (A.OPER { assem = assemCode oper,
                                                                                src = [munchExp e1, munchExp e2],
                                                                                dst = [r],
                                                                                jump = NONE }))
                                              end
        | munchExp (T.CONST i) = result (fn r => emit (A.OPER { assem = "ldr 'd0, =" ^ Int.toString(i) ^ "\n",
                                                                src = [],
                                                                dst = [r],
                                                                jump = NONE }))
        | munchExp (T.NAME l) = result (fn r => emit (A.OPER { assem = "ldr 'd0, =" ^ l ^ "\n",
                                                               src = [],
                                                               dst = [r],
                                                               jump = NONE }))
        | munchExp (T.TEMP t) = t
        | munchExp _ = raise Fail "No debería llegar! (munchExp2)"

      and munchArgs (n, xs) = muchArgAux (map (fn (x,y) => let val w = exp x (T.TEMP fp) in munchStm (T.MOVE (w, y)); w end) (ListPair.zip (formals(frame), xs)))

  in munchStm stm;
     rev(!ilist)
  end


fun maximalMunch f [] = []
  | maximalMunch f ((h as T.CJUMP _)::_::t) = codegen f h @ maximalMunch f t  (* No importa el segundo elemento de la lista porque éste siempre será el label false del CJUMP *)
  | maximalMunch f (h::t) = codegen f h @ maximalMunch f t
      
end
