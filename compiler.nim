from os import existsFile, existsDir, createDir, copyFile, commandLineParams
import location
import sets
import ASTNode
import tables
import nodeTypes
from tokenTypes as Tok import nil
import ptlsError
import strutils
import sequtils
import tokenizer
import parser

type
  Env* = ref object of RootObj
    parent: Env
    prelude: Env
    globals: Env
    defs: HashSet[string]

# Environment Methods
# --------------------------
proc createEnv(parent: Env = nil) : Env =
  var env = Env(parent: parent)
  let prelude = if isNil(parent): env
                elif isNil(parent.prelude): env
                else: parent.prelude
  let globals = if isNil(parent): env
                elif isNil(parent.globals): env
                else: parent.globals
  env.prelude = prelude
  env.globals = globals
  return env

proc addDefName(this: Env, name: string, loc: Location) =
  if this.defs.contains(name):
    let error = returnPtlsError("Name Error");
    error.msg = "Duplicate definition for name '" & name[0..len(name)-2] & "'"
    error.locs.add(loc)
    raise error;
  this.defs.incl(name)

proc spawn(this: Env) : Env = createEnv(this)

proc clone(this: Env) : Env =
  let copyEnv = createEnv(this.parent)
  for value in this.defs:
    copyEnv.defs.incl(value)
  return copyEnv

proc existsDefName(this: Env, name: string, loc: Location) =
  var searchEnv = this

  while searchEnv != nil:
    if searchEnv.defs.contains(name):
      return

    searchEnv = searchEnv.parent

  let error = returnPtlsError("Name Error");
  error.locs.add(loc)
  error.msg = "No definition for name '" & name[0..len(name)-2] & "'"
  raise error

# Forward Declarations
# -----------------------
proc compile(program: string, name: string, main: bool) : string
proc declare(env: Env, node: ASTNode, main: bool, traceLocs: seq[Location] = @[]) : string
proc dispatch(immut_env: Env, immut_node: ASTNode, main: bool, immut_traceLocs: seq[Location] = @[]) : string
proc validate(env: Env, node: ASTNode, main: bool, traceLocs: seq[Location] = @[]) : bool{.discardable.}
proc appendOne(env: Env, node: ASTNode, main: bool, traceLocs: seq[Location] = @[]) : bool{.discardable.}
proc eval[T](env: Env, node: ASTNode, fun: proc(env: Env, node: ASTNode, main: bool, immut_traceLocs: seq[Location] = @[]) : T = dispatch, main: bool = false) : T{.discardable.}

# Declarator, it forward declares functions
proc declare(env: Env, node: ASTNode, main: bool, traceLocs: seq[Location] = @[]) : string =
  if node.NodeType == Program:
    var decls = ""
    for imp in node.imports:
      eval[string](env, imp, fun = declare)
    for def in node.defs:
      let lhs = eval[string](env, def.lhs, fun = declare)
      decls.add("local " & lhs & ";\n")
    return decls
  elif node.NodeType == Name:
    env.addDefName(node.identifier, node.location)
    return node.identifier
  elif node.NodeType == Tuple:
    var decls = node.tuple_elems.map(proc(s: ASTNode) : string = s.identifier).join(", ")
    for elem in node.tuple_elems:
      env.addDefName(elem.identifier, node.location)
    return decls
  elif node.NodeType == Func:
    var decls = node.func_params.map(proc(s: ASTNode) : string = s.identifier).join(", ")
    for param in node.func_params:
      env.addDefName(param.identifier, node.location)
    return decls
  elif node.NodeType == Import:
    env.addDefName(node.as_node.identifier, node.location)
    return ""
  else:
    quit "No declaration for " & $node.NodeType & " avalible"


# Undeclared variabele error
proc noDefinition(name : string, loc : Location) =
  let error = returnPtlsError("Name Error");
  error.msg = "No definition for name '" & name[0..len(name)-2] & "'"
  error.locs.add(loc)
  raise error

proc checkNoDefinition(env : Env, name : string, loc: Location) =
  existsDefName(env, name, loc)
  return

# Appends one to every variable name, for reasons
proc appendOne(env: Env, node: ASTNode, main: bool, traceLocs: seq[Location] = @[]) : bool{.discardable.} =
  case node.NodeType:
    of Node.Array:
      for elem in node.array_elems:
        eval[bool](env, elem, fun = appendOne)
      return

    of Node.BinaryOp:
      eval[bool](env, node.bin_lhs, fun = appendOne)
      eval[bool](env, node.bin_rhs, fun = appendOne)
      return

    of Node.Bool:
      return

    of Node.Call:
      eval[bool](env, node.reference, fun = appendOne)
      for arg in node.refered:
        eval[bool](env, arg, fun = appendOne)
      return

    of Node.Conditional:
      eval[bool](env, node.ifClause, fun = appendOne)
      eval[bool](env, node.thenExpr, fun = appendOne)
      if node.elseExpr != nil:
        eval[bool](env, node.elseExpr, fun = appendOne)
      return

    of Node.Dict:
      for pair in node.dict_elems:
        eval[bool](env, pair.key, fun = appendOne)
        eval[bool](env, pair.val, fun = appendOne)
      return

    of Node.Export:
      for exp in node.exports:
        eval[bool](env, exp, fun = appendOne)
      return

    of Node.FieldRef:
      eval[bool](env, node.label, fun = appendOne)
      return

    of Node.Func:
      let new_env = env.spawn()
      eval[string](new_env, node, fun = declare)
      eval[bool](new_env, node.fun_body, fun = appendOne)
      for param in node.func_params:
        eval[bool](new_env, param, fun = appendOne)
      return

    of Node.Import:
      if not existsFile(node.path.strValue):
        let error = returnPtlsError("Import Error")
        error.msg = "No file at '" & node.path.strValue & "' exists"
        error.locs.add(node.location)
        raise error
      eval[bool](env, node.as_node, fun = appendOne)
      return

    of Node.Index:
      eval[bool](env, node.index_lhs, fun = appendOne)

    of Node.Label:
      return

    of Node.List:
      for elem in node.list_elems:
        eval[bool](env, elem, fun = appendOne)
      return

    of Node.Name:
      node.identifier &= "1"
      return

    of Node.Number:
      return

    of Node.Object:
      let new_env = env.spawn()
      for def in node.obj_defs:
        eval[bool](new_env, def.rhs, fun = appendOne)
      let programNode = ASTNode(NodeType: Node.Program, defs: node.obj_defs, export_name: nil)
      return

    of Node.Program:
      for n in node.imports:
        eval[bool](env, n, fun = appendOne)

      for def in node.defs:
        eval[bool](env, def.lhs, fun = appendOne)
        eval[bool](env, def.rhs, fun = appendOne)

      if not isNil(node.export_name):
        eval[bool](env, node.export_name, fun = appendOne)
      return

    of Node.Requires:
      eval[bool](env, node.requirement, fun = appendOne)
      eval[bool](env, node.required, fun = appendOne)

    of Node.Set:
      for elem in node.set_elems:
        eval[bool](env, elem, fun = appendOne)
      return

    of Node.String:
      return

    of Node.Throw:
      eval[bool](env, node.thrown_error, fun = appendOne)

    of Node.Try:
      eval[bool](env, node.trial_body, fun = appendOne)
      eval[bool](env, node.catch_condition, fun = appendOne)
      eval[bool](env, node.handler, fun = appendOne)

    of Node.Tuple:
      for elem in node.tuple_elems:
        eval[bool](env, elem, fun = appendOne)
      return

    of Node.UnaryOp:
      eval[bool](env, node.unary_node, fun = appendOne)
      return

    of Node.Where:
      let new_env = env.spawn()
      let programNode = ASTNode(NodeType: Node.Program, defs: node.where_clause.obj_defs, export_name: nil)
      eval[string](new_env, programNode, fun = declare)
      eval[bool](new_env, programNode, fun = appendOne)
      eval[bool](new_env, node.where_body, fun = appendOne)
      return

    of Node.With:
      eval[bool](env, node.with_body, fun = appendOne)
      for def in node.with_defs:
        eval[bool](env, def.rhs, fun = appendOne)
      return

    of Node.Pair: quit "We hate pairs"
    of Node.Blank: quit "We hate blanks"
    of Node.Def: quit "We hate defs"

# Make sure no undeclared variables are used
proc validate(env: Env, node: ASTNode, main: bool, traceLocs: seq[Location] = @[]) : bool{.discardable.} =
  case node.NodeType:
    of Node.Array:
      for elem in node.array_elems:
        eval[bool](env, elem, fun = validate)
      return

    of Node.BinaryOp:
      eval[bool](env, node.bin_lhs, fun = validate)
      eval[bool](env, node.bin_rhs, fun = validate)
      return

    of Node.Bool:
      return

    of Node.Call:
      eval[bool](env, node.reference, fun = validate)
      for arg in node.refered:
        eval[bool](env, arg, fun = validate)
      return

    of Node.Conditional:
      eval[bool](env, node.ifClause, fun = validate)
      eval[bool](env, node.thenExpr, fun = validate)
      if node.elseExpr != nil:
        eval[bool](env, node.elseExpr, fun = validate)
      return

    of Node.Dict:
      for pair in node.dict_elems:
        eval[bool](env, pair.key, fun = validate)
        eval[bool](env, pair.val, fun = validate)
      return

    of Node.Export:
      for exp in node.exports:
        eval[bool](env, exp, fun = validate)
      return

    of Node.FieldRef:
      eval[bool](env, node.label, fun = validate)
      return

    of Node.Func:
      let new_env = env.spawn()
      eval[string](new_env, node, fun = declare)
      eval[bool](new_env, node.fun_body, fun = validate)
      return

    of Node.Import:
      if not existsFile(node.path.strValue):
        let error = returnPtlsError("Import Error")
        error.msg = "No file at '" & node.path.strValue & "' exists"
        error.locs.add(node.location)
        raise error
      return

    of Node.Index:
      eval[bool](env, node.index_lhs, fun = validate)

    of Node.Label:
      return

    of Node.List:
      for elem in node.list_elems:
        eval[bool](env, elem, fun = validate)
      return

    of Node.Name:
      checkNoDefinition(env, node.identifier, node.location)
      return

    of Node.Number:
      return

    of Node.Object:
      let new_env = env.spawn()
      let programNode = ASTNode(NodeType: Node.Program, defs: node.obj_defs, export_name: nil)
      eval[string](new_env, programNode, fun = declare)
      eval[bool](new_env, programNode, fun = validate)
      return

    of Node.Program:
      for n in node.imports:
        eval[bool](env, n, fun = validate)

      for def in node.defs:
        eval[bool](env, def.lhs, fun = validate)
        eval[bool](env, def.rhs, fun = validate)

      if not isNil(node.export_name):
        eval[bool](env, node.export_name, fun = validate)
      return

    of Node.Requires:
      eval[bool](env, node.requirement, fun = validate)
      eval[bool](env, node.required, fun = validate)

    of Node.Set:
      for elem in node.set_elems:
        eval[bool](env, elem, fun = validate)
      return

    of Node.String:
      return

    of Node.Throw:
      eval[bool](env, node.thrown_error, fun = validate)

    of Node.Try:
      eval[bool](env, node.trial_body, fun = validate)
      eval[bool](env, node.catch_condition, fun = validate)
      eval[bool](env, node.handler, fun = validate)

    of Node.Tuple:
      for elem in node.tuple_elems:
        eval[bool](env, elem, fun = validate)
      return

    of Node.UnaryOp:
      eval[bool](env, node.unary_node, fun = validate)
      return

    of Node.Where:
      let new_env = env.spawn()
      let programNode = ASTNode(NodeType: Node.Program, defs: node.where_clause.obj_defs, export_name: nil)
      eval[string](new_env, programNode, fun = declare)
      eval[bool](new_env, programNode, fun = validate)
      eval[bool](new_env, node.where_body, fun = validate)
      return

    of Node.With:
      eval[bool](env, node.with_body, fun = validate)
      for def in node.with_defs:
        eval[bool](env, def.rhs, fun = validate)
      return

    of Node.Pair: quit "We hate pairs"
    of Node.Blank: quit "We hate blanks"
    of Node.Def: quit "We hate defs"

# Binary Operation handler
proc handleUnaryOp(env: Env, op: Tok.Tok, operandNode: ASTNode) : string =
  if op.str == Tok.Neg.str:
    let operand = eval[string](env, operandNode)
    return operand & ":negate(" & operand & ")"
  elif op.str == Tok.Not.str:
    let operand = eval[string](env, operandNode)
    return operand & ":notted(" & operand & ")"

  quit op.str & "isn't quite an operator that I am familiar with"

proc handleBinaryOp(env: Env, op: Tok.Tok, lhsNode: ASTNode, rhsNode: ASTNode) : string =
  var res : string
  if op.str == Tok.Concat.str:
    let lhs = eval[string](env, lhsNode)
    let rhs = eval[string](env, rhsNode)
    res = lhs & ":concat(PtlsThunk.create(function() return " & rhs & " end))"

  elif op.str == Tok.Or.str:
    let lhs = eval[string](env, lhsNode)
    let rhs = eval[string](env, rhsNode)
    res = lhs & ":ored(" & rhs & ")"

  elif op.str == Tok.And.str:
    let lhs = eval[string](env, lhsNode)
    let rhs = eval[string](env, rhsNode)
    res = lhs & ":anded(" & rhs & ")"

  elif op.str == Tok.Equals.str:
    let lhs = eval[string](env, lhsNode)
    let rhs = eval[string](env, rhsNode)
    res = lhs & ":equaled(" & rhs & ")"

  elif op.str == Tok.NotEq.str:
    let lhs = eval[string](env, lhsNode)
    let rhs = eval[string](env, rhsNode)
    res = lhs & ":notEqualed(" & rhs & ")"

  elif op.str == Tok.In.str:
    let lhs = eval[string](env, lhsNode)
    let rhs = eval[string](env, rhsNode)
    res = lhs & ":inside(" & rhs & ")"

  elif op.str == Tok.LessThan.str:
    let lhs = eval[string](env, lhsNode)
    let rhs = eval[string](env, rhsNode)
    res = lhs & ":lessThaned(" & rhs & ")"

  elif op.str == Tok.LessEq.str:
    let lhs = eval[string](env, lhsNode)
    let rhs = eval[string](env, rhsNode)
    res = lhs & ":lessEqualed(" & rhs & ")"

  elif op.str == Tok.GreaterThan.str:
    let lhs = eval[string](env, lhsNode)
    let rhs = eval[string](env, rhsNode)
    res = lhs & ":greaterThaned(" & rhs & ")"

  elif op.str == Tok.GreaterEq.str:
    let lhs = eval[string](env, lhsNode)
    let rhs = eval[string](env, rhsNode)
    res = lhs & ":greaterEqualed(" & rhs & ")"

  elif op.str == Tok.Add.str:
    let lhs = eval[string](env, lhsNode)
    let rhs = eval[string](env, rhsNode)
    res = lhs & ":added(" & rhs & ")"

  elif op.str == Tok.Sub.str:
    let lhs = eval[string](env, lhsNode)
    let rhs = eval[string](env, rhsNode)
    res = lhs & ":subbed(" & rhs & ")"

  elif op.str == Tok.Mul.str:
    let lhs = eval[string](env, lhsNode)
    let rhs = eval[string](env, rhsNode)
    res = lhs & ":muled(" & rhs & ")"

  elif op.str == Tok.Div.str:
    let lhs = eval[string](env, lhsNode)
    let rhs = eval[string](env, rhsNode)
    res = lhs & ":dived(" & rhs & ")"

  elif op.str == Tok.Mod.str:
    let lhs = eval[string](env, lhsNode)
    let rhs = eval[string](env, rhsNode)
    res = lhs & ":modded(" & rhs & ")"

  elif op.str == Tok.Pow.str:
    let lhs = eval[string](env, lhsNode)
    let rhs = eval[string](env, rhsNode)
    res = lhs & ":powed(" & rhs & ")"

  else:
    quit op.str & "isn't quite an operator that I am familiar with"

  return "(" & res & ")"

# The actual interpreter
# -----------------------
var depth = 0
var lastLoc : Location

proc eval[T](env: Env, node: ASTNode, fun: proc(env: Env, node: ASTNode, main: bool, immut_traceLocs: seq[Location] = @[]) : T = dispatch, main: bool = false) : T{.discardable.} =
  let maxDepth = 1000
  if depth > maxDepth:
    let error = returnPtlsError("Recursion Error")
    error.msg = "Max call depth " & $maxDepth & " exceeded"
    raise error
  try:
    return fun(env, node, main)
  except PtlsError:
    raise

proc update(env: Env, accessor: ASTNode, res: string): string =
  var new_res = res
  if accessor.NodeType == Node.Name:
    return res

  let lhs = eval[string](env, accessor[0])

  if accessor.NodeType == Node.Index:
    let index = eval[string](env, accessor[1])
    new_res = lhs & ":updateIndex(" & index & ", " & new_res & ")"
  else:
    let name = $accessor.field.identifier
    new_res = lhs & ":updateField(\"" & name & "\", " & new_res & ")"
  return update(env, accessor[0], new_res)

proc dispatch(immut_env: Env, immut_node: ASTNode, main: bool, immut_traceLocs: seq[Location] = @[]) : string =
  var env = immut_env
  var node = immut_node
  while true:
    lastLoc = node.location
    case node.NodeType:
      of Node.Array:
        let ptls_array_seq = "{" & node.array_elems.map(proc(n: ASTNode) : string = eval[string](env, n)).join(", ") & "}"
        return "(" & "PtlsArray.fromSet(" & ptls_array_seq & ")" & node.location.luaLoc() & ")"

      of Node.BinaryOp:
        return handleBinaryOp(env, node.binary_op, node.bin_lhs, node.bin_rhs)

      of Node.Bool:
        return  "(" & "PtlsBool.create(" & $node.boolValue & ")" & node.location.luaLoc() & ")"

      of Node.Call:
        return "(" & eval[string](env, node.reference) & node.refered.map(proc(n: ASTNode) : string = "(PtlsThunk.create(function() return " & eval[string](env, n) & " end))").join("") & ")"

      of Node.Conditional:
        let condition = eval[string](env, node.ifClause)
        var str =  "function() return " & condition & ":is_true() end, function() return " & eval[string](env, node.thenExpr) & " end"
        if node.elseExpr != nil:
          str.add(", function() return " & eval[string](env, node.elseExpr) & " end")
        return "if_expression(" & str & ")"

      of Node.Dict:
        return "(PtlsDict.create({" & node.dict_elems.map(proc(n: ASTNode) : string = "[" & eval[string](env, n.key) & "] = " & eval[string](env, n.val)).join(";\n") & "})" &
          node.location.luaLoc() & ")"

      of Node.FieldRef:
        let lhs = eval[string](env, node.label)
        let name = node.field.identifier
        return "(" & lhs & ":getProperty(\"" & name & "\")()" & node.location.luaLoc() & ")"

      of Node.Func:
        var function = ""
        var counter = 0
        for param in node.func_params:
          if counter > 0:
            function.add("return PtlsFunc.create(function (" & param.identifier & ") ")
          else:
            function.add("PtlsFunc.create(function (" & param.identifier & ") ")
          counter += 1
        function.add("return " & eval[string](env, node.fun_body))
        for _ in 1..counter:
          function.add(" end)" & node.location.luaLoc() & " ")
        return function

      of Node.Index:
        let lhs = eval[string](env, node.index_lhs)
        let rhs = eval[string](env, node.index_rhs)
        return "(" & lhs & ":getIndex(" & rhs & ")" & node.location.luaLoc() & ")"

      of Node.Label:
        return "(PtlsLabel.create(\"" & node.labelValue & "\")" & node.location.luaLoc() & ")"

      of Node.List:
        let ptls_array_seq = "{" & node.list_elems.map(proc(n: ASTNode) : string = eval[string](env, n)).join(", ") & "}"
        return "(" & "PtlsList.fromValues(" & ptls_array_seq & ")" & node.location.luaLoc() & ")"

      of Node.Name:
        return node.identifier & "()"

      of Node.Number:
        return "(" & "PtlsNumber.create(" & $node.numValue & ")" & node.location.luaLoc() & ")"

      of Node.Object:
        return "(" & "PtlsObject.create({" & node.obj_defs.map(proc(n: ASTNode) : string =
          if n.lhs.NodeType == Tuple:
            let lhs = n.lhs.tuple_elems.map(proc(n: ASTNode) : string = n.identifier).join(", ")
            let rhs = "PtlsValue.unwrap(" & eval[string](env, n.rhs) & ", " & $len(n.lhs.tuple_elems) & ")"
            return lhs & " = " & rhs & ";\n"
          else:
            let lhs = eval[string](env, n.lhs)
            return lhs[0..len(lhs)-3] & " = PtlsThunk.create(function() return " & eval[string](env, n.rhs) & " end) ;\n"
        ).join("\n") & "})" & node.location.luaLoc() & ")"

      of Node.Program:
        let exports = node.export_name
        let imports = node.imports
        let defs = node.defs

        var evaluated_imports = ""
        var evaluated_defs = ""
        var evaluated_export = ""

        for importNode in imports:
          evaluated_imports.add("local " & importNode.as_node.identifier & " = PtlsThunk.create(function() return (PtlsObject.create(" & eval[string](env, importNode) & ")" &
            node.location.luaLoc() & ") ;\n end)")

        for defNode in defs:
          if defNode.lhs.NodeType == Tuple:
            let lhs = defNode.lhs.tuple_elems.map(proc(n: ASTNode) : string = n.identifier).join(", ")
            let rhs = "PtlsValue.unwrap(" & eval[string](env, defNode.rhs) & ", " & $len(defNode.lhs.tuple_elems) & ")"
            evaluated_defs.add(lhs & " = " & rhs & ";\n")
          else:
            let lhs = eval[string](env, defNode.lhs)
            evaluated_defs.add(lhs[0..len(lhs)-3] & " = PtlsThunk.create(function() return " & eval[string](env, defNode.rhs) & " end) ;\n")

        if exports == nil:
          var exp = "return {"
          for name in env.defs:
            let obj = "['" & name[0..len(name)-2] & "'] = " & name & ";\n"
            exp.add(obj)
          exp.add("};")
          evaluated_export = exp
        else:
          var exp = "return {"
          for nameNode in exports.exports:
            let obj = "['" & nameNode.identifier & "'] = " & nameNode.identifier[0..len(nameNode.identifier)-2] & ";\n"
            exp.add(obj)
          exp.add("};")
          evaluated_export = exp

        let between = if main: "try(\n\toutput1, \n\tfunction(err) \n\t\tprint(debug.traceback())\n\t\tprint(err.getError == nil and err or err:getError())\n\t\tos.exit()\n\tend\n):getOutput()\n"
                      else: "\n"
        return evaluated_imports & "\n" & evaluated_defs & between & evaluated_export

      of Node.Requires:
        let condition = eval[string](env, node.requirement)
        let action = eval[string](env, node.required)
        return condition & ":is_true() and " & action & " or error(PtlsError.create(\"Unmet Condition\", \"\", PtlsNumber.create(0)" & node.location.luaLoc() & "))"

      of Node.Set:
        return "(PtlsSet.create({" & node.set_elems.map(proc(n: ASTNode) : string = eval[string](env, n)).join(", ") & "})" & node.location.luaLoc() & ")"

      of Node.String:
        return "(PtlsString.create" & "(" & "\"" & node.strValue & "\"" & ")" & node.location.luaLoc() & ")"

      of Node.Throw:
        let value = eval[string](env, node.thrown_error)
        return "(error(PtlsError.create('Uncaught Error', '', " & value & ")))"

      of Node.Try:
        let trial_body = eval[string](env, node.trial_body)
        let catch_condition = eval[string](env, node.catch_condition)
        let handler = eval[string](env, node.handler)
        return """try(
          """ & "function() return " & trial_body & " end" & """,
          function(err)
            local caught__ = function() return err.value end;
            local err__ = function() return err end;
            return ((""" & catch_condition & """)(caught__):is_true() and ((""" & handler & """)(caught__)) or error(err__()))
          end
        )"""

      of Node.Tuple:
        return "(PtlsTuple.create({" & node.tuple_elems.map(proc(n: ASTNode) : string = "PtlsThunk.create(function() return " & eval[string](env, n) & " end)").join(", ") & "})" &
          node.location.luaLoc() & ")"

      of Node.UnaryOp:
        return handleUnaryOp(env, node.op, node.unary_node)

      of Node.Where:
        var defs = ""
        defs.add(eval[string](env.spawn(), ASTNode(NodeType: Node.Program, defs: node.where_clause.obj_defs, imports: @[], export_name: nil), fun = declare) & "\n")
        for defNode in node.where_clause.obj_defs:
          if defNode.lhs.NodeType == Tuple:
            let lhs = defNode.lhs.tuple_elems.map(proc(n: ASTNode) : string = n.identifier).join(", ")
            let rhs = "PtlsValue.unwrap(" & eval[string](env, defNode.rhs) & ", " & $len(defNode.lhs.tuple_elems) & ")"
            defs.add(lhs & " = " & rhs & ";\n")
          else:
            let lhs = eval[string](env, defNode.lhs)
            defs.add(lhs[0..len(lhs)-3] & " = PtlsThunk.create(function() return " & eval[string](env, defNode.rhs) & " end) ;\n")
        return "(function() \n" & defs & "\nreturn " & eval[string](env, node.where_body) & "\nend)()"

      of Node.With:
        let newEnv = env.spawn()
        var all_defs = @["local meta__ = " & eval[string](env, node.with_body)]
        let values = node.with_defs.map(proc(n: ASTNode) : string = eval[string](newEnv, n.rhs))
        var index = 0
        for def in node.with_defs:
          var variable_current_def = values[index]
          all_defs.add("meta__ = " & update(newEnv, def.lhs, variable_current_def).replace("$()", "meta__"))
          if index == len(values)-1:
            all_defs.add("return meta__")
          index += 1
        return "(function()\n" & all_defs.join(";\n") & "\n" & "end)()"

      of Node.Import:
        let split_name = node.path.strValue.split(".")[0]
        let chars = @(readFile(node.path.strValue)).filter(proc(x: char) : bool = x != '\r').join("")
        let compiled_text = "require 'PtlsRuntime'\n\n" & compile(chars, node.path.strValue, false)
        if not existsDir("output"):
          createDir("output")
        writeFile("output/" & split_name & ".lua", compiled_text)
        return "require '" & split_name & "'"

      of Node.Pair: quit "We hate pairs"
      of Node.Blank: quit "We hate blanks"
      of Node.Def: quit "We hate defs"
      of Node.Export: quit "We hate exports"

proc compile(program: string, name: string, main: bool) : string =
  let toks = getToks(program, name)
  let ast = makeast(toks)
  let env = createEnv()
  discard eval[bool](env, ast, fun = appendOne)
  var declarations : string
  try:
    declarations = eval[string](env, ast, fun = declare)
    discard eval[bool](env, ast, fun = validate)
    if main:
      checkNoDefinition(env, "output1", ast.location)
  except PtlsError as err:
    echo err.locs.deduplicate.join("\n")
    raise
  var code = eval[string](env, ast, main = main)
  return "local filename__ = '" & name & "'\n" & declarations & "\n" & code

let commands = commandLineParams().map(proc(x: TaintedString) : string = $x)
if len(commands) != 1:
  quit "Wrong amount of parameters, the correct format is, [compiler-name] [file-name]"

if not existsFile(commands[0]):
  let error = returnPtlsError("IO Error")
  error.msg = "The file " & commands[0] & " doesn't exist"
  raise error

let name = commands[0].split(".")[0]
let program = @(readFile(commands[0])).filter(proc(x: char) : bool = x!='\r').join("")
let compiled_text = "require 'PtlsRuntime'\n" & compile(program, name, true)
if not existsDir("output"):
  createDir("output")
copyFile("PtlsRuntime.lua", "output/PtlsRuntime.lua")
copyFile("hashLib.lua", "output/luaHash.lua")
writeFile("output/" & name & ".lua", compiled_text)
echo compiled_text
