structure tigerseman :> tigerseman =
struct

open tigerabs
open tigersres

type expty = {exp: unit, ty: Tipo}

type venv = (string, EnvEntry) tigertab.Tabla
type tenv = (string, Tipo) tigertab.Tabla

val tab_tipos : (string, Tipo) Tabla = tabInserList(
tabNueva(),
[("int", TInt), ("string", TString)])

val tab_vars : (string, EnvEntry) Tabla = tabInserList(
tabNueva(),
[("print", Func{level=mainLevel, label="print",
		formals=[TString], result=TUnit, extern=true}),
 ("flush", Func{level=mainLevel, label="flush",
		formals=[], result=TUnit, extern=true}),
 ("getchar", Func{level=mainLevel, label="getstr",
		  formals=[], result=TString, extern=true}),
 ("ord", Func{level=mainLevel, label="ord",
	      formals=[TString], result=TInt, extern=true}),
 ("chr", Func{level=mainLevel, label="chr",
	      formals=[TInt], result=TString, extern=true}),
 ("size", Func{level=mainLevel, label="size",
	       formals=[TString], result=TInt, extern=true}),
 ("substring", Func{level=mainLevel, label="substring",
		    formals=[TString, TInt, TInt], result=TString, extern=true}),
 ("concat", Func{level=mainLevel, label="concat",
		 formals=[TString, TString], result=TString, extern=true}),
 ("not", Func{level=mainLevel, label="not",
	      formals=[TInt], result=TInt, extern=true}),
 ("exit", Func{level=mainLevel, label="exit",
	       formals=[TInt], result=TUnit, extern=true})
])

fun tipoReal (TTipo (s, ref (SOME (t)))) = tipoReal t
  | tipoReal t = t

fun tiposIguales (TRecord _) TNil = true
  | tiposIguales TNil (TRecord _) = true 
  | tiposIguales (TRecord (_, u1)) (TRecord (_, u2 )) = (u1=u2)
  | tiposIguales (TArray (_, u1)) (TArray (_, u2)) = (u1=u2)
  | tiposIguales (TTipo (_, r)) b =
    let
	val a = case !r of
		    SOME t => t
		  | NONE => raise Fail "No debería pasar! (1)"
    in
	tiposIguales a b
    end
  | tiposIguales a (TTipo (_, r)) =
    let
	val b = case !r of
		    SOME t => t
		  | NONE => raise Fail "No debería pasar! (2)"
    in
	tiposIguales a b
    end
  | tiposIguales a b = (a=b)

fun transExp(venv, tenv) =
    let fun error(s, p) = raise Fail ("Error -- línea "^Int.toString(p)^": "^s^"\n")
	fun trexp(VarExp v) = trvar(v)
	  | trexp(UnitExp _) = {exp=(), ty=TUnit}
	  | trexp(NilExp _)= {exp=(), ty=TNil}
	  | trexp(IntExp(i, _)) = {exp=(), ty=TInt}
	  | trexp(StringExp(s, _)) = {exp=(), ty=TString}
	  | trexp(CallExp({func = f, args = xs}, nl)) =		
	    (* NOSOTROS *)		
	    let
		val {formals = argsType, result = resultType, ...} =
		    case tabBusca(f,venv) of
			SOME (Func e) => e
		      | NONE => error("Función no declarada", nl)
		      | _ => error("No es una función", nl)
		fun compararListaTipos [] [] = true
		  | compararListaTipos _ [] = error("Mayor cantidad de argumentos", nl)
		  | compararListaTipos [] _ = error("Menor cantidad de argumento", nl)
		  | compararListaTipos (x::xs) (y::ys) =
                    let val {ty = expType, ...} = trexp x
                    in
		        if tiposIguales expType y then
                            compararListaTipos xs ys
		        else
                            false 
                    end
	    in
		if (compararListaTipos xs argsType) then
		    {exp=(), ty = TFunc (argsType, resultType)}
		else
		    error("Distintos tipos", nl)
	    end
	  | trexp(OpExp({left, oper=EqOp, right}, nl)) =
	    let
		val {exp=_, ty=tyl} = trexp left
		val {exp=_, ty=tyr} = trexp right
	    in
		if tiposIguales tyl tyr andalso not (tyl=TNil andalso tyr=TNil) andalso tyl<>TUnit then {exp=(), ty=TInt}
		else error("Tipos no comparables", nl)
	    end
	  | trexp(OpExp({left, oper=NeqOp, right}, nl)) = 
	    let
		val {exp=_, ty=tyl} = trexp left
		val {exp=_, ty=tyr} = trexp right
	    in
		if tiposIguales tyl tyr andalso not (tyl=TNil andalso tyr=TNil) andalso tyl<>TUnit then {exp=(), ty=TInt}
		else error("Tipos no comparables", nl)
	    end
	  | trexp(OpExp({left, oper, right}, nl)) = 
	    let
		val {exp=_, ty=tyl} = trexp left
		val {exp=_, ty=tyr} = trexp right
	    in
		if tiposIguales tyl tyr then
		    case oper of
			PlusOp => if tipoReal tyl=TInt then {exp=(),ty=TInt} else error("Error de tipos", nl)
		      | MinusOp => if tipoReal tyl=TInt then {exp=(),ty=TInt} else error("Error de tipos", nl)
		      | TimesOp => if tipoReal tyl=TInt then {exp=(),ty=TInt} else error("Error de tipos", nl)
		      | DivideOp => if tipoReal tyl=TInt then {exp=(),ty=TInt} else error("Error de tipos", nl)
		      | LtOp => if tipoReal tyl=TInt orelse tipoReal tyl=TString then {exp=(),ty=TInt} else error("Error de tipos", nl)
		      | LeOp => if tipoReal tyl=TInt orelse tipoReal tyl=TString then {exp=(),ty=TInt} else error("Error de tipos", nl)
		      | GtOp => if tipoReal tyl=TInt orelse tipoReal tyl=TString then {exp=(),ty=TInt} else error("Error de tipos", nl)
		      | GeOp => if tipoReal tyl=TInt orelse tipoReal tyl=TString then {exp=(),ty=TInt} else error("Error de tipos", nl)
		      | _ => raise Fail "No debería pasar! (3)"
		else error("Error de tipos", nl)
	    end
	  | trexp(RecordExp({fields, typ}, nl)) =
	    let
		(* Traducir cada expresión de fields *)
		val tfields = map (fn (sy,ex) => (sy, trexp ex)) fields

		(* Buscar el tipo *)
		val (tyr, cs) = case tabBusca(typ, tenv) of
				    SOME t => (case tipoReal t of
						   TRecord (cs, u) => (TRecord (cs, u), cs)
						 | _ => error(typ^" no es de tipo record", nl))
				  | NONE => error("Tipo inexistente ("^typ^")", nl)
				                 
		(* Verificar que cada campo esté en orden y tenga una expresión del tipo que corresponde *)
		fun verificar [] [] = ()
		  | verificar (c::cs) [] = error("Faltan campos", nl)
		  | verificar [] (c::cs) = error("Sobran campos", nl)
		  | verificar ((s,t,_)::cs) ((sy,{exp,ty})::ds) =
		    if s<>sy then error("Error de campo", nl)
		    else if tiposIguales ty t then verificar cs ds
		    else error("Error de tipo del campo "^s, nl)
		val _ = verificar cs tfields
	    in
		{exp=(), ty=tyr}
	    end
	  | trexp(SeqExp(s, nl)) =
	    let	val lexti = map trexp s
		val exprs = map (fn{exp, ty} => exp) lexti
		val {exp, ty=tipo} = hd(rev lexti)
	    in	{ exp=(), ty=tipo } end
	  (* | trexp(AssignExp({var = SimpleVar s, exp = e}, nl)) = *)
          (* Este caso es al cuete, lo contempla el caso general *)
	  | trexp(AssignExp ({var, exp}, nl)) =
	    (*NOSOTROS*)
            let
                val {ty = expType, ...} = trexp exp
		val {ty = varType, ...} = trvar (var,nl)
            in
		if tiposIguales expType varType then
                    {exp=(), ty = TUnit }
		else
		    error("Error de tipos en asignación", nl)
            end
	  | trexp(IfExp({test, then', else'=SOME else'}, nl)) =
	    let val {exp=testexp, ty=tytest} = trexp test
		val {exp=thenexp, ty=tythen} = trexp then'
		val {exp=elseexp, ty=tyelse} = trexp else'
	    in
		if tipoReal tytest=TInt andalso tiposIguales tythen tyelse then {exp=(), ty=tythen}
		else error("Error de tipos en if" ,nl)
	    end
	  | trexp(IfExp({test, then', else'=NONE}, nl)) =
	    let val {exp=exptest,ty=tytest} = trexp test
		val {exp=expthen,ty=tythen} = trexp then'
	    in
		if tipoReal tytest=TInt andalso tythen=TUnit then {exp=(), ty=TUnit}
		else error("Error de tipos en if", nl)
	    end
	  | trexp(WhileExp({test, body}, nl)) =
	    let
		val ttest = trexp test
		val tbody = trexp body
	    in
		if tipoReal (#ty ttest) = TInt andalso #ty tbody = TUnit then {exp=(), ty=TUnit}
		else if tipoReal (#ty ttest) <> TInt then error("Error de tipo en la condición", nl)
		else error("El cuerpo de un while no puede devolver un valor", nl)
	    end
	  | trexp(ForExp({var, lo = e1, hi = e2, body = e3}, nl)) =
	    (* NOOSOTROS *)
            let
                val {ty = tipo1, ...} = trexp e1
                val {ty = tipo2, ...} = trexp e2
                val {ty = tipo3, ...} = trexp e3
                val {ty = varType , ...} = trvar (var,nl)
                (* aca hay que comparar que varType, tipo1 y tipo2 sean de tipo int, el resto no se *)
	  | trexp(LetExp({decs, body}, _)) =
	    let
		val (venv', tenv', _) = List.foldl (fn (d, (v, t, _)) => trdec(v, t) d) (venv, tenv, []) decs
		val {exp=expbody,ty=tybody}=transExp (venv', tenv') body
	    in 
		{exp=(), ty=tybody}
	    end
	  | trexp(BreakExp nl) =
	    {exp=(), ty=TUnit} (*COMPLETAR*)
	  | trexp(ArrayExp({typ, size, init}, nl)) =
	    {exp=(), ty=TUnit} (*COMPLETAR*)
	and trvar(SimpleVar s, nl) =
            (* NOSOTROS *)
            let
		val varType =
		    case tabBusca (s, venv) of
			SOME (Var {ty = t}) => t
                      | SOME (VIntro) => TInt (*esta bien?*)
                      | SOME _ => error ("Variable inválida", nl)
		      | NONE => error("Variable inexistente", nl)
            in
		{exp=(), ty=varType}
            end
	  | trvar(FieldVar(v, s), nl) =
	    {exp=(), ty=TUnit} (*COMPLETAR*)
	  | trvar(SubscriptVar(v, e), nl) =
	    {exp=(), ty=TUnit} (*COMPLETAR*)
	and trdec (venv, tenv) (VarDec ({name,escape,typ=NONE,init},pos)) = 
	    (venv, tenv, []) (*COMPLETAR*)
	  | trdec (venv,tenv) (VarDec ({name,escape,typ=SOME s,init},pos)) =
	    (venv, tenv, []) (*COMPLETAR*)
	  | trdec (venv,tenv) (FunctionDec fs) =
	    (venv, tenv, []) (*COMPLETAR*)
	  | trdec (venv,tenv) (TypeDec ts) =
	    (venv, tenv, []) (*COMPLETAR*)
    in trexp end
fun transProg ex =
    let	val main =
	    LetExp({decs=[FunctionDec[({name="_tigermain", params=[],
					result=NONE, body=ex}, 0)]],
		    body=UnitExp 0}, 0)
	(*val _ = transExp(tab_vars, tab_tipos) main*)
	val _ = transExp(tab_vars, tab_tipos) ex (* despues hay que cambiarlo *)
    in	print "bien!\n" end
end
