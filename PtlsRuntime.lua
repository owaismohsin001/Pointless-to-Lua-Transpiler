hash = require("luaHash")

ticks = 0

function map(tbl, f)
    local t = {}
    for k,v in pairs(tbl) do
        t[k] = f(v)
    end
    return t
end

function if_expression(cond, act_true, act_false)
  condition = cond()
  if condition then
    return act_true()
  else
    if act_false == nil then error(PtlsError.create("Match Error", "None of the avalible conditions matched" .. condition.type_, condition)) end
    return act_false()
  end
end

function try(f, catch_f)
  local status, exception = pcall(f)
  if not status then
    return catch_f(exception)
  end
  return f()
end

function PtlsValueCall(this, ...)
  return error(PtlsError.create("Type Error", "Can't call a value of type " .. this.type_, this))
end

function locate(this, location)
  this.loc = location
  return this
end

function reversed(iterable)
  local i = tablelength(iterable)-1
  local reversed_iterable = {}
  local counter = 0
  while i >= 0 do
    reversed_iterable[counter] = iterable[i]
    i = i-1
    counter = counter + 1
  end
  return reversed_iterable
end

function checkType(expected, val)
  if expected ~= val.type_ then error(PtlsError.create("TypeError", "expected " .. expected .. " got " .. val.type_, val)) end
  return val
end

function make_set(iterable)
  local set = {}
  for _, v in pairs(iterable) do
    set[v] = v
  end
  return set
end

function make_iterable(set)
  local iterable = {}
  local counter = 0
  for k, v in pairs(set) do
    iterable[counter] = v
    counter = counter + 1
  end
  return iterable
end

function table_eq(one, two)

    if type(one) == type(two) then
        if type(one) == "table" then
            if #one == #two then

                -- If both types are the same, both are tables and
                -- the tables are the same size, recurse through each
                -- table entry.
                for loop=1, #one do
                    if table_eq (one[loop], two[loop]) == false then
                        return false
                    end
                end

                -- All table contents match
                return true
            end
        else
            -- Values are not tables but matching types. Compare
            -- them and return if they match
            return one == two
        end
    end
    return false
end

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function contains(set, key)
    return set[key] ~= nil
end

function copy(obj, seen)
    -- Handle non-tables and previously-seen tables.
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end

    -- New table; mark it as seen and copy recursively.
    local s = seen or {}
    local res = {}
    s[obj] = res
    for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
    return setmetatable(res, getmetatable(obj))
end

function tryOrError(fun)
  local status, err = pcall(fun)
  if not status then
    print(debug.traceback())
    print(err:getError())
    os.exit()
    return
  end
  return
end

PtlsLocation = {}
function PtlsLocation.create(ln, cn, fn)
  this = {
    ln = ln;
    cn = cn;
    fn = fn;
  }
  this.toString = function(this)
    return "In \"" .. fn .. "\" on line no. " .. ln .. " at column no. " .. cn
  end
  return this
end

PtlsValue = {
  metatable = {
        __index = PtlsValue;
        __call = PtlsValueCall;
    };
    type_ = "Value";
    added = function(this, other)
              error(PtlsError.create("TypeError", "Cannot add " .. this.type_ .. " to " .. other.type_, this))
            end;

    subbed = function(this, other)
              error(PtlsError.create("TypeError", "Cannot substract " .. this.type_ .. " from " .. other.type_, this))
            end;

    muled = function(this, other)
              error(PtlsError.create("TypeError", "Cannot multiply " .. this.type_ .. " with " .. other.type_, this))
            end;

    dived = function(this, other)
              error(PtlsError.create("TypeError", "Cannot divide " .. this.type_ .. " by " .. other.type_, this))
            end;

    negate = function(this)
      error(PtlsError.create("TypeError", "Can't negate " .. this.type_, this))
    end;

    is_lazy_arg = false;

    notted = function(this)
      error(PtlsError.create("TypeError", "Can't not " .. this.type_, this))
    end;

    modded = function(this, other)
              error(PtlsError.create("TypeError", "Cannot mod " .. this.type_ .. " by " .. other.type_, this))
            end;

    powed = function(this, other)
              error(PtlsError.create("TypeError", "Cannot raise " .. this.type_ .. " to the power of " .. other.type_, this))
            end;

    equaled = function(this, other)
              return PtlsBool.create(false)
            end;

    lessThaned = function(this, other)
              error(PtlsError.create("TypeError", "Cannot quantify " .. this.type_ .. " and " .. other.type_ .. " with appropriate quantities for '<'", this))
            end;

    lessEqualed = function(this, other)
              error(PtlsError.create("TypeError", "Cannot quantify " .. this.type_ .. " and " .. other.type_ .. " with appropriate quantities for '<='", this))
            end;

    greaterThaned = function(this, other)
              error(PtlsError.create("TypeError", "Cannot quantify " .. this.type_ .. " and " .. other.type_ .. " with appropriate quantities for '>'", this))
            end;

    greaterEqualed = function(this, other)
              error(PtlsError.create("TypeError", "Cannot quantify " .. this.type_ .. " and " .. other.type_ .. " with appropriate quantities for '>='", this))
            end;

    notEqualed = function(this, other)
              return PtlsBool.create(true)
            end;

    anded = function(this, other)
      error(PtlsError.create("TypeError", "Can't make 'and' of " .. this.type_ .. " and " .. other.type_, this))
    end;

    ored = function(this, other)
      error(PtlsError.create("TypeError", "Can't make 'or' of " .. this.type_ .. " and " .. other.type_, this))
    end;

    inside = function(this, other)
      error(PtlsError.create("TypeError", "Can't check if " .. this.type_ .. "is in other " .. other.type_, this))
    end;

    getProperty = function(this, other)
              error(PtlsError.create("KeyError", "Cannot get the property " .. other .. " of " .. this.type_, this))
            end;

    getIndex = function(this, other)
      error(PtlsError.create("KeyError", "Cannot get the index " .. other.value .. " from " .. this.type_, this))
    end;

    updateIndex = function(this, other, res)
      error(PtlsError.create("KeyError", "Cannot get the index " .. other.value .. " from " .. this.type_, this))
    end;

    delKey = function(this, other)
      error(PtlsError.create("KeyError", "Cannot get the index " .. other .. " from " .. this.type_, this))
    end;

    concat = function(this, other)
      error(PtlsError.create("TypeError", "Cannot concatenate " .. this.type_ .. " to " .. other.type_, this))
    end;

    isEmpty = function(this) return false end;

    is_true = function(this)
      error(PtlsError.create("TypeError", "Expected bool but got " .. this.type_, this))
    end;

    unwrap = function(this, args)
      tryOrError(function() return checkType("PtlsTuple", this) end)
      tryOrError(function() return this.checkLength(this, args) end)
      return unpack(this.value)
    end;

    toList = function(this)
      error(PtlsError.create("TypeError", "Expected PtlsList but got " .. this.type_, this))
    end;

    unhashables = 0;

    getHash = function(this)
      this.unhashables = this.unhashables + 1
      return "Unhashable" .. tostring(this.unhashables) .. this.type_
    end;

    toString = function(this)
      error(PtlsError.create("TypeError", "Can't print Value as a string " .. this.type_, this))
    end;

    getOutput = function(this)
      print("TypeError: " .. this.type_ .. " cannot be used as output, use a list instead")
      os.exit()
    end;

     sameTypes = function (this, other, fun)
              other = other or this
              if other.type_ == this.type_ then
                return true
              end
              return fun(this, other)
            end;
}

PtlsError = {}
PtlsError.__index = PtlsValue
function PtlsError.create(errorType, message, value)
  local this = setmetatable({
    err = errorType;
    message = message;
    value = value;
  }, PtlsError)

  this.getError = function(this)
    if this.value.loc == nil then
      return this.err .. ": " .. this.message
    elseif this.err == 'Uncaught Error' and this.message == '' then
      return this.value.loc:toString() .. "\n" .. this.err .. ": " .. this.value:toString()
    elseif this.message == "" then
      return this.value.loc:toString() .. "\n" .. this.err
    else
      return this.value.loc:toString() .. "\n" .. this.err .. ": " .. this.message
    end
  end

  setmetatable(this, {
    __index = PtlsValue;
  })
  return this
end

PtlsThunk = {}
PtlsThunk.__index = PtlsValue
function  PtlsThunk.create(fun)
  local this = setmetatable({
    type_ = "PtlsThunk";
    fun = fun;
    value = nil;
  }, PtlsThunk)

  setmetatable(this, {
    __index = PtlsValue;
    __call = function(this, ...)
      if this.value == nil then
        this.value = this.fun(...)
      end
      return this.value
    end
  })
  return this
end;

PtlsFunc = {}
PtlsFunc.__index = PtlsValue
function  PtlsFunc.create(fun)
  local this = setmetatable({
    fun = fun;
    values = {};
    type_ = "PtlsFunc";
    value = elems;
    properties = {
      ["!getType"] = function(this) return function() return PtlsLabel.create("PtlsFunc") end end;
    };
  }, PtlsThunk)

  this.getProperty = function(this, other)
    if contains(this.properties, other) then return this.properties[other](this) end
    return PtlsValue.getProperty(this, other)
  end;

  this.locate = function(this, location) return locate(this, location) end;

  this.toString = function(this)
    return "<function>"
  end

  this.getValue = function(this, arg)
    if arg().is_lazy_arg then return nil end
    return this.values[arg():getHash()]
  end

  setmetatable(this, {
    __index = PtlsValue;
    __call = function(this, arg)
      val = this:getValue(arg)
      if val ~= nil then return val end
      lastTicks = ticks
      res = this.fun(arg)
      if ticks == lastTicks then
        local hash = arg():getHash()
        this.values[hash] = res
      end
      return res
    end
  })
  return this
end;

PtlsBuiltIn = {}
PtlsBuiltIn.__index = PtlsValue
function PtlsBuiltIn.create(fun)
  local this = setmetatable({
    fun = fun;
    values = {};
    type_ = "PtlsBuiltIn";
    value = elems;
    properties = {
      ["!getType"] = function(this) return function() return PtlsLabel.create("PtlsBuiltIn") end end;
    };
  }, PtlsThunk)

  this.getProperty = function(this, other)
    if contains(this.properties, other) then return this.properties[other](this) end
    return PtlsValue.getProperty(this, other)
  end;

  this.locate = function(this, location) return locate(this, location) end;

  this.toString = function(this)
    return "<built-in function>"
  end

  setmetatable(this, {
    __index = PtlsValue;
    __call = function(this, ...)
      return this.fun(...)
    end
  })
  return this
end;

PtlsArray = {}
PtlsArray.__index = PtlsValue

PtlsArray.fromSet = function(set)
    return PtlsArray.create(make_iterable(set))
end

PtlsArray.create = function(elems)
  local this = setmetatable({
    type_ = "PtlsArray";
    value = elems;
    properties = {
    ["!getList"] = function(this) return function() return PtlsList.fromValues(this.value) end end;
    ["!getTuple"] = function(this) return function() return PtlsTuple.create(this.value) end end;
    ["!getType"] = function(this) return function() return PtlsLabel.create("PtlsArray") end end;
    ["!getLength"] = function(this) return function() return PtlsNumber.create(tablelength(this.value)) end end;
    };
  }, PtlsArray)

  this.getHash = function(this)
    local str = ""
    local i = 0
    local length = tablelength(this.value)
    while i < length do
      str = str .. this.value[i]:getHash()
      i = i+1
    end
    return str .. "IsAnArray"
  end

  this.getProperty = function(this, other)
    if contains(this.properties, other) then return this.properties[other](this) end
    return PtlsValue.getProperty(this, other)
  end;

  this.checkIndex = function(this, index)
    if index.type_ ~= "PtlsNumber" then return PtlsValue.getIndex(this, index) end
    if index.value < 0 or index.value >= tablelength(this.value) then return PtlsValue.getIndex(this, index) end
    return index
  end;

  this.updateIndex = function(this, index, res)
    local ind = this.checkIndex(this, index)
    local c = copy(this.value)
    c[ind.value] = res
    return PtlsArray.create(c):locate(this.loc)
  end;

  this.getIndex = function(this, other)
    index = this.checkIndex(this, other)
    return this.value[index.value]
  end;

  this.equaled = function(this, other)
    if other.type_ ~= this.type_ then return PtlsBool.create(false):locate(this.loc) end
    return PtlsBool.create(table_eq(this.value, other.value)):locate(this.loc)
  end;

  this.locate = function(this, location) return locate(this, location) end

  this.toString = function(this)
    local str = ""
    local i = 0
    local length = tablelength(this.value)
    while i < length do
      str = str .. this.value[i]:toString()
      if i ~= length-1 then
        str = str .. " "
      end
      i = i+1
    end
    return "[" .. str .. "]"
  end

  setmetatable(this, {
    __index = PtlsValue;
    __call = PtlsValueCall;
  })
  return this
end

PtlsBool = {}
PtlsBool.__index = PtlsValue
function PtlsBool.create(val)
  local this = setmetatable({
    type_ = "PtlsBool";
    value = val;
    properties = {
    ["!getInt"] = function(this) return function() return this.value and PtlsNumber.create(1) or PtlsNumber.create(0) end end;
    ["!getFloat"] = function(this) return function() return value and PtlsNumber.create(1.0) or PtlsNumber.create(0.0) end end;
    ["!getString"] = function(this) return function() return value and PtlsString.create("true") or PtlsString.create("false") end end;
    ["!getType"] = function(this) return function() return PtlsLabel.create("PtlsBool") end end;
  };
}, PtlsBool)

  this.getProperty = function(this, other)
    if contains(this.properties, other) then return this.properties[other](this) end
    return PtlsValue.getProperty(this, other)
  end;

  this.getHash = function(this) return hash.sha1(tostring(this.value)) .. "IsABool" end

  this.notted = function(this)
    return PtlsBool.create(not this.value):locate(this.loc)
  end

  this.anded = function(this, other)
    PtlsValue.sameTypes(this, other, this.anded)
    return PtlsBool.create(this.value and other.value):locate(this.loc)
  end

  this.ored = function(this, other)
    PtlsValue.sameTypes(this, other, this.ored)
    return PtlsBool.create(this.value or other.value):locate(this.loc)
  end

  this.equaled = function(this, other)
    if this.type_ == other.type_ then
      return PtlsBool.create(this.value == other.value):locate(this.loc)
    end
    return PtlsBool.create(false):locate(this.loc)
  end;

  this.notEqualed = function(this, other)
    return PtlsBool.create(not (this:equaled(other).value)):locate(this.loc)
  end;

  this.is_true = function(this)
    return this.value
  end;

  this.locate = function(this, location) return locate(this, location) end

  this.toString = function(this)
    if this.value then
      return "true"
    else
      return "false"
    end
  end;

  setmetatable(this, {
    __index = PtlsValue;
    __call = PtlsValueCall;
  })
  return this
end;

PtlsDict = {}
PtlsDict.__index = PtlsValue
PtlsDict.create = function(obj)
  local this = setmetatable({
    type_ = "PtlsDict";
    value = obj;
    properties = {
      ["!getDelKey"] =
      function(this)
        return function()
          return function(n)
            return this.delKey(this, n()) end
          end
        end;
      ["!getKeys"] = function(this)
        return function()
          local keys = {}
          for k, _ in pairs(this.value) do
            keys.insert(k)
          end
          return PtlsList.create(keys)
          end
        end;
      ["!getVals"] = function(this)
        return function()
          local vals = {}
          for _, v in pairs(this.value) do
            keys.insert(v)
          end
          return PtlsList.create(vals)
          end
        end;
      ["!getLength"] = function(this) return function() return PtlsNumber.create(tablelength(this.value)) end end;
      ["!getType"] = function(this) return function() return PtlsLabel.create("PtlsDict") end end;
    };
  }, PtlsDict)

  this.getProperty = function(this, other)
    if contains(this.properties, other) then return this.properties[other](this) end
    return PtlsValue.getProperty(this, other)
  end;

  this.getHash = function(this, other)
    local str = ""
    local length = tablelength(this.value)
    local count = 0
    for k, v in pairs(this.value) do
      str = str .. (k:getHash() .. "colon" .. v:getHash())
      count = count + 1
    end
    return str .. "IsADict"
  end;

  this.inside = function(this, other)
    for k, v in pairs(this.value) do
      if v.equaled(v, other) then return PtlsBool.create(true):locate(this.loc) end
    end
    return PtlsBool.create(false):locate(this.loc)
  end;

  this.getIndex = function(this, other)
    for k, v in pairs(this.value) do
      local equality = k.equaled(k, other)
      if equality.is_true(equality) then return v end
    end
    return PtlsValue.getIndex(this, other)
  end;

  this.updateIndex = function(this, other, res)
    local dict = copy(this.value)
    for k, v in pairs(dict) do
      local equality = k.equaled(k, other):locate(this.loc)
      if equality.is_true(equality) then
        dict[k] = nil
      end
    end
    dict[other] = res
    return PtlsDict.create(dict):locate(this.loc)
  end;

  this.delKey = function(this, other)
    local dict = copy(this.value)
    for k, v in pairs(dict) do
      local equality = k.equaled(k, other):locate(this.loc)
      if equality.is_true(equality) then
          dict[k] = nil
      end
    end
    return PtlsDict.create(dict):locate(this.loc)
  end;

  this.equaled = function(this, other)
    if this.type_ ~= other.type_ then return PtlsBool.create(false):locate(this.loc) end
    for k, v in pairs(this.value) do
      if not (other.contains(other, k).value) then return PtlsBool.create(false):locate(this.loc) end
      if not (v.equaled(v, other.getIndex(other, k))).value then return PtlsBool.create(false):locate(this.loc) end
    end
    return PtlsBool.create(true):locate(this.loc)
  end;

  this.notEqualed = function(this, other)
    return PtlsBool.create(not (this.equaled(this, other).value)):locate(this.loc)
  end;

  this.locate = function(this, location) return locate(this, location) end

  this.toString = function(this, other)
    local str = ""
    local length = tablelength(this.value)
    local count = 0
    for k, v in pairs(this.value) do
      str = str .. (k:toString() .. " : " .. v:toString())
      if length-1 ~= count then
        str = str .. ", "
      end
      count = count + 1
    end
    return "{" .. str .. "}"
  end;

  setmetatable(this, {
      __index = PtlsValue;
    __call = PtlsValueCall;
  })
  return this
end;

PtlsSet = {}
PtlsSet.__index = PtlsValue
PtlsSet.create = function(value)
  local this = setmetatable({
    type_ = "PtlsSet";
    value = make_set(value);
    properties = {
      ["!getAddElem"] = function(this) return function() return PtlsBuiltIn.create(function(inp) return this.addElem(this, inp()) end) end end;
      ["!getDelElem"] = function(this) return function() return PtlsBuiltIn.create(function(inp) return this.delElem(this, inp()) end) end end;
      ["!getType"] = function(this) return function() return PtlsLabel.create("PtlsArray") end end;
      ["!getLength"] = function(this) return function() return PtlsNumber.create(tablelength(this.value)) end end;
      ["!getList"] = function(this) return function() return PtlsList.fromValues(this.value) end end;
    };
  }, PtlsSet)

  this.getProperty = function(this, other)
    if contains(this.properties, other) then return this.properties[other](this) end
    return PtlsValue.getProperty(this, other)
  end;

  this.toString = function(this)
    local tb = {}
    for k, v in pairs(make_set(this.value)) do
      table.insert(tb, v:getHash())
    end
    return table.concat(tb, "") .. "IsASet"
  end

  this.inside = function(this, other)
    for k, v in pairs(this.value) do
      if k.equaled(other) and v.equaled(other) then return PtlsBool.create(true):locate(this.loc) end
    end
    return PtlsBool.create(false):locate(this.loc)
  end;

  this.addElem = function(this, elem)
    local new_set = copy(this.value)
    new_set[elem] = elem
    return PtlsSet.create(new_set):locate(this.loc)
  end;

  this.delElem = function(this, elem)
    local new_set = copy(this.value)
    new_set[elem] = nil
    return PtlsSet.create(new_set):locate(this.loc)
  end;

  this.equaled = function(this, other)
    if this.type_ ~= other.type_ then return PtlsBool.create(false):locate(this.loc) end
    return PtlsBool.create(table_eq(this.value, other.value)):locate(this.loc)
  end;

  this.notEqualed = function(this, other)
    return PtlsBool.create(not (this.equaled(other).value)):locate(this.loc)
  end;

  this.locate = function(this, location) return locate(this, location) end

  this.toString = function(this)
    local tb = {}
    for k, v in pairs(make_set(this.value)) do
      table.insert(tb, v:toString())
    end
    return "{" .. table.concat(tb, ", ") .. "}"
  end

  setmetatable(this, {
      __index = PtlsValue;
      __call = PtlsValueCall;
  })
  return this
end

PtlsLabel = {}
PtlsLabel.__index = PtlsValue
PtlsLabel.create = function(value)
  local this = setmetatable({
    type_ = "PtlsLabel";
    value = value;
    properties = {
      ["!getReadFile"] = function(this)
        this.checkLabel(this, "IO", "!getReadFile")
        return function()
          return PtlsBuiltIn.create(
            function(inp)
              ticks = ticks + 1
              return this.readFile(this, inp, false)
          end)
        end
      end;

      ["!getReadFileLines"] = function(this)
        this.checkLabel(this, "IO", "!getReadFileLines")
        return function()
          return PtlsBuiltIn.create(
            function(inp)
              ticks = ticks + 1
              return this.readFile(this, inp, true)
            end
          )
        end
      end;

      ["!getDebug"] = function(this)
        this.checkLabel(this, "IO", "!getDebug")
        return function()
          return PtlsBuiltIn.create(
            function(inp)
              ticks = ticks + 1
              return this.getDebug(this, inp)
            end
          )
        end
      end;

      ["!getRand"] = function(this)
        this.checkLabel(this, "IO", "!getRand")
        ticks = ticks + 1
         return function() return PtlsNumber.create(math.random(0, 100)) end
      end;

      ["!getSet"] = function(this)
        this.checkLabel(this, "IO", "!getRand")
        ticks = ticks + 1
        return function() return PtlsSet.create({}) end
      end;

      ["!getSet"] = function(this)
        this.checkLabel(this, "Empty", "!getSet")
        ticks = ticks + 1
        return function() return PtlsSet.create({}) end
      end;

      ["!getZeros"] = function(this)
        this.checkLabel(this, "PtlsArray", "!getZeros")
        return function()
          return PtlsBuiltIn.create(
            function(inp)
              return this.getZeros(this, inp)
            end
          )
        end
      end;

      ["!getString"] = function(this) return function() return PtlsString.create(this.value) end end;
      ["!getType"] = function(this) return function() return PtlsLabel.create("PtlsLabel") end end;

      ["!getWrap"] = function(this)
        return function()
          return PtlsBuiltIn.create(
            function(inp)
              return this.getWrap(this, inp)
            end
          )
        end
      end;

      ["!getWrapTuple"] = function(this)
        return function()
          return PtlsBuiltIn.create(
            function(inp)
              return this.getWrapTuple(this, inp)
            end
          )
        end
      end;

      ["!getWrapObject"] = function(this)
        return function()
          return PtlsBuiltIn.create(
            function(inp)
              return this:getWrapObject(inp)
            end
          )
        end
      end;
    };
  }, PtlsLabel)

  this.getProperty = function(this, other)
    if not contains(this.properties, other) then return PtlsValue.getProperty(this, other) end
    return this.properties[other](this)
  end;

  this.isEmpty = function(this) return this.value == "Empty" end;

  this.checkIsList = function(this)
    if this.isEmpty(this) then return this end
    PtlsValue.checkIsList(this)
  end;

  this.getZeros = function(this, val)
    local n = checkType("PtlsNumber", val()).value
    local i = 0
    local table = {}
    while i<n do
      table[i] = 0
      i = i+1
    end
    return PtlsArray.create(table):locate(this.loc)
  end;

  this.getDebug = function(this, val)
    print(val():toString())
    return val()
  end;

  this.readFile = function(this, path, getLines)
    checkType("PtlsTuple", path())
    local file = io.open(path, "rb")
    if file == nil then
      error(PtlsError.create("IOError", "Can't read file at '" .. path() .. "'", this))
    end
    local lines = {}
    for line in io.lines(file) do
      lines[#lines + 1] = line
    end
    if getLines then
      return PtlsList.fromValues(lines)
    end
    return PtlsString.create(table.concat(lines, "\n"))
  end;

  this.checkLabel = function(this, val, name)
    if (this.value ~= val) then
      error(PtlsError.create("TypeError", "No built-in field " .. name .. "' for label '" .. value .. "'", this))
    end
  end;

  this.getLines = function(this)
    local line = io.read()
    if line == "" then return PtlsLabel.create("Empty") end
    local head = function() return PtlsString.create(line) end
    local tail = this.getLines
    return PtlsList.direct(head, tail)
  end;

  this.getWrap = function(this, value) return PtlsTuple.create({value()}, this):locate(this.loc) end;

  this.getWrapTuple = function(this, tuple)
    checkType("PtlsTuple", tuple())
    return PtlsTuple.create(copy(tuple().value), this):locate(this.loc)
  end;

  this.getHash = function(this, obj)
    return hash.sha1(this.value) .. "IsALabal"
  end

  this.equaled = function(this, other)
    if this.type_ ~= other.type_ then return PtlsBool.create(false):locate(this.loc) end
    return PtlsBool.create(this.value == other.value):locate(this.loc)
  end;

  this.notEqualed = function(this, other)
    return PtlsBool.create(not this.equaled(this, other).value):locate(this.loc)
  end;

  this.getWrapObject = function(this, obj)
    checkType("PtlsObject", obj())
    return PtlsObject.create(copy(obj().value), this):locate(this.loc)
  end;

  this.locate = function(this, location) return locate(this, location) end

  this.toString = function(this, obj)
    return this.value
  end

  setmetatable(this, {
      __index = PtlsValue;
  })
  return this
end

PtlsObject = {}
PtlsObject.__index = PtlsValue
PtlsObject.create = function(obj, label)
  local this = setmetatable({
    type_ = "PtlsObject";
    label = label or PtlsLabel.create("PtlsObject");
    value = obj;
    properties = {
      ["!getDict"] = function(this)
        return function()
          local new_dict = copy(this.value, this.value)
          local ptlsTyped = {}
          for k, v in pairs(new_dict) do
            ptlsTyped[PtlsString.create(k)] = v()
          end
          return PtlsDict.create(ptlsTyped)
        end
      end;
      ["!getLabel"] = function(this) return function() return this.label end end;
      ["!getType"] = function(this) return function() return PtlsLabel.create("PtlsObject") end end;
    };
  }, PtlsObject)

  this.getProperty = function(this, other)
    if contains(this.properties, other) then return this.properties[other](this) end
    return this.value[other]
  end;

  this.getHash = function(this, other)
    local str = ""
    local counter = 0
    local length = tablelength(this.value)
    for k, v in pairs(this.value) do
      str = str .. (hash.sha1(k) .. "equals" .. v():getHash())
      counter = counter + 1
    end
    return this.label:getHash() .. (str .. "IsAnObject")
  end;

  this.updateField = function(this, name, res)
    local newEnv = copy(this.value)
    if contains(newEnv, name) then
      newEnv[name] = nil
    end
    newEnv[name] = function() return res end
    return PtlsObject.create(newEnv, this.label):locate(this.loc)
  end;

  this.equaled = function(this, other)
    if this.type_ ~= other.type_ then return PtlsBool.create(false):locate(this.loc) end
    if not (this.label.equaled(this.label, other.label).value) then return PtlsBool.create(false):locate(this.loc) end
    local this_obj = {}
    local other_obj = {}
    for k, v in pairs(this.value) do
      this_obj[k] = v()
    end
    for k, v in pairs(other.value) do
      other_obj[k] = v()
    end
    for k, v in pairs(this_obj) do
      if not contains(other_obj, k)then return PtlsBool.create(false):locate(this.loc) end
      if not (v.equaled(v, other_obj[k]).value) then return PtlsBool.create(false):locate(this.loc) end
    end
    return PtlsBool.create(true):locate(this.loc)
  end;

  this.notEqualed = function(this, other)
      return PtlsBool.create(not (this.equaled(this, other).value)):locate(this.loc)
  end;

  this.locate = function(this, location) return locate(this, location) end

  this.toString = function(this, other)
    local str = ""
    local counter = 0
    local length = tablelength(this.value)
    for k, v in pairs(this.value) do
      str = str .. (k .. " = " .. v():toString())
      if counter ~= length-1 then
        str = str .. ", "
      end
      counter = counter + 1
    end
    return (this.label.value == "PtlsObject" and "" or this.label:toString()) .. "{" .. str .. "}"
  end;

  setmetatable(this, {
      __index = PtlsValue;
      __call = PtlsValueCall;
  })
  return this
end;

PtlsString = {}
PtlsString.__index = PtlsValue
PtlsString.create = function(strValue)
  local this = setmetatable({
    type_ = "PtlsString";
    value = strValue;
    properties = {
      ["!getInt"] = function(this) return function() return PtlsNumber.create(math.floor((tonumber(this.value) * 10) / 10)) end end;
      ["!getFloat"] = function(this) return function() return PtlsNumber.create(tonumber(this.value)) end end;
      ["!getString"] = function(this) return function() return PtlsString.create(this.value) end end;
      ["!getType"] = function(this) return function() return PtlsLabel.create("PtlsString") end end;
      ["!getLength"] = function(this) return function() return PtlsNumber.create(this.value.len()) end end;
    };
  }, PtlsString)

  this.getProperty = function(this, other)
      if not contains(this.properties, other) then return PtlsValue.getProperty(this, other) end
      return this.properties[other](this)
    end;

  this.getHash = function(this) return hash.sha1(this.value) .. "IsAString" end  

  this.added = function(this, other)
    PtlsValue.sameTypes(this, other, PtlsValue.added)
    return PtlsString.create(this.value .. other.value):locate(this.loc)
  end;

  this.equaled = function(this, other)
    if this.type_ ~= other.type_ then return PtlsBool.create(false):locate(this.loc) end
    return PtlsBool.create(this.value == other.value):locate(this.loc)
  end;

  this.notEqualed = function(this, other)
    return PtlsBool.create(not (this.equaled(this, other).value)):locate(this.loc)
  end;

  this.locate = function(this, location) return locate(this, location) end

  this.toString = function(this)
    return '"' .. this.value .. '"'
  end

  setmetatable(this, {
    __index = PtlsValue;
    __call = PtlsValueCall;
  })
  return this
end

PtlsTuple = {}
PtlsTuple.create = function(tuple, label)
  local this = setmetatable({
    type_ = "PtlsTuple";
    value = tuple;
    label = label or PtlsLabel.create("PtlsTuple");
    properties = {
      ["!getLabel"] = function(this) return function() return this.label end end;
      ["!getType"] = function(this) return function() return PtlsLabel.create("PtlsTuple") end end;
      ["!getLength"] = function(this) return function() return PtlsNumber.create(tablelength(this.value)) end end;
      ["!getList"] = function(this)
        return function()
          local new_tuple = copy(this.value)
          for k, v in pairs(new_tuple) do
            new_tuple[k] = v()
          end
          return PtlsList.fromValues(new_tuple)
          end
        end;
    };
  }, PtlsTuple)

  this.getHash = function(this)
    return (this.label.value == "PtlsTuple" and "" or this.label:getHash()) .. (table.concat(map(this.value, function(x) return x():getHash() end), "") .. "IsATuple")
  end;

  this.getProperty = function(this, other)
    if not contains(this.properties, other) then return PtlsValue.getProperty(this, other) end
    return this.properties[other](this)
  end;

  this.checkLength = function(this, length)
    if length ~= tablelength(this.value) then
      error(PtlsError.create("TypeError", "Cannot destructure length " .. tostring(tablelength(this.value)) .. " tuple to " .. length .. " names", this))
    end
    return this
  end;

  this.getIndex = function(this, index)
    checkType("PtlsNumber", index)
    return this.value[index.value]
  end;

  this.equaled = function(this, other)
    checkType("PtlsTuple", this)
    if not other.label.equaled(other.label, this.label) then return PtlsBool.create(false):locate(this.loc) end
    local this_tuple = copy(this.value)
    local other_tuple = copy(other.value)
    for k, v in pairs(this_tuple) do
      this_tuple[k] = v()
    end
    for k, v in pairs(other_tuple) do
      other_tuple[k] = v()
    end
    for k, v in pairs(this_tuple) do
      if not contains(other_tuple, k) then return PtlsBool.create(false):locate(this.loc) end
      if not (v.equaled(v, other_tuple[k]).value) then return PtlsBool.create(false):locate(this.loc) end
    end
    return PtlsBool.create(true):locate(this.loc)
  end;

  this.notEqualed = function(this, other)
    return PtlsBool.create(not this.equaled(this, other)):locate(this.loc)
  end;

  this.locate = function(this, location) return locate(this, location) end

  this.toString = function(this)
    return (this.label.value == "PtlsTuple" and "" or this.label:toString()) .. "(" .. table.concat(map(this.value, function(x) return x():toString() end), ", ") .. ")"
  end;

  setmetatable(this, {
    __index = PtlsValue;
    __call = PtlsValueCall;
  })
  return this
end

PtlsList = {}
PtlsList.__index = PtlsValue

PtlsList.fromValues = function(values)
  local result = PtlsLabel.create("Empty")
  local list = reversed(make_iterable((values)))
  local length = tablelength(list)
  local i = 0
  while i<length do
    local headThunk = list[i]
    local tailThunk = result
    result = PtlsList.create(headThunk, tailThunk)
    i = i+1
  end
  return result
end

PtlsList.direct = function(head, tail)
  local list = PtlsList.create("nil", "nil")
  list.head = head
  list.tail = tail
  return list
end

PtlsList.create = function(head, tail)
  local this = setmetatable({
      head = function(this) return head end;
      tail = function(this) return tail end;
      is_lazy_arg = true;
      type_ = "PtlsList";

      properties = {
        ["!getHead"] = function(this) return function() return this.head(this) end end;
        ["!getTail"] = function(this) return function() return this.tail(this) end end;
        ["!getList"] = function(this) return function() return this end end;
        ["!getType"] = function(this) return function() return PtlsLabel.create("PtlsList") end end;
      };
    }, PtlsList)

  this.getProperty = function(this, other)
      if not contains(this.properties, other) then return PtlsValue.getProperty(this, other) end
      return this.properties[other](this)
    end;

  this.toList = function(this)
    local tailIter = this.tail(this)
    local result = {this.head(this)}
    while not tailIter.isEmpty(tailIter) do
      table.insert(result, tailIter.head(tailIter))
      tailIter = tailIter.tail(tailIter)
    end
    return result
  end;

  this.concat = function(this, other)
    local tail = this.tail(this)
    if tail.isEmpty(tail) then
      local tailThunk = other
      local x = PtlsList.direct(PtlsThunk.create(function() return this.head(this) end), tailThunk):locate(this.loc)
      return x
    end
    local thunk = PtlsThunk.create(function() return tail.concat(tail, other) end)
    return PtlsList.direct(PtlsThunk.create(function() return this.head(this) end), thunk):locate(this.loc)
  end;

  this.equaled = function(this, other)
    if other.type_ ~= this.type_ then return PtlsBool.create(false):locate(this.loc) end
    local this_seq = make_iterable(this.toList(this))
    local other_seq = make_iterable(other.toList(other))
    for k, v in pairs(this_seq) do
      if not contains(other_seq, k) then return PtlsBool.create(false):locate(this.loc) end
      if not v.equaled(v, other_seq[k]).value then return PtlsBool.create(false):locate(this.loc) end
    end
    return PtlsBool.create(true):locate(this.loc)
  end;

  this.notEqualed = function(this, other)
    return PtlsBool.create(not (this.equaled(this, other).value)):locate(this.loc)
  end;

  this.locate = function(this, location) return locate(this, location) end

  this.getOutput = function(this)
    local output = this
    while output.type_ == "PtlsList" do
      print(output:head():toString())
      output = output:tail()
    end
    return
  end;

  this.toString = function(this)
    return "[" .. table.concat(map(this:toList(), function(x) return x:toString() end), ", ") .. "]"
  end;

  setmetatable(this, {
      __index = PtlsValue;
      __call = PtlsValueCall;
  })
  return this
end


PtlsNumber = {}
PtlsNumber.__index = PtlsValue

function PtlsNumber.create(num)
  local this = setmetatable({
    type_ = "PtlsNumber";
    value = num;
    properties = {
      ["!getInt"] = function(this) return function() return PtlsNumber.create(math.floor((this.value * 10) / 10)) end end;
      ["!getFloat"] = function(this) return function() return PtlsNumber.create(this.value/1) end end;
      ["!getAsin"] = function(this) return function() return PtlsNumber.create(math.asin(this.value)) end end;
      ["!getAcos"] = function(this) return function() return PtlsNumber.create(math.acos(this.value)) end end;
      ["!getAtan"] = function(this) return function() return PtlsNumber.create(math.atan(this.value)) end end;
      ["!getSin"] = function(this) return function() return PtlsNumber.create(math.sin(this.value)) end end;
      ["!getCos"] = function(this) return function() return PtlsNumber.create(math.cos(this.value)) end end;
      ["!getTan"] = function(this) return function() return PtlsNumber.create(math.tan(this.value)) end end;
      ["!getLn"] = function(this) return function() return PtlsNumber.create(math.log(this.value)) end end;
      ["!getString"] = function(this) return function() return PtlsNumber.create(toString(this.value)) end end;
      ["!getType"] = function(this) return function() return PtlsLabel.create("PtlsNumber") end end;
    }
  }, PtlsNumber)

  this.getProperty = function(this, other)
    if not contains(this.properties, other) then return PtlsValue.getProperty(this, other) end
    return this.properties[other](this)
  end;

  this.added = function(this, other)
    PtlsValue.sameTypes(this, other, PtlsValue.added)
    return PtlsNumber.create(this.value + other.value):locate(this.loc)
  end;

  this.subbed = function(this, other)
    PtlsValue.sameTypes(this, other, PtlsValue.subbed)
    return PtlsNumber.create(this.value - other.value):locate(this.loc)
  end;

  this.muled = function(this, other)
    PtlsValue.sameTypes(this, other, PtlsValue.muled)
    return PtlsNumber.create(this.value * other.value):locate(this.loc)
  end;

  this.dived = function(this, other)
    PtlsValue.sameTypes(this, other, PtlsValue.dived)
    if other.value == 0 then
      error(PtlsError.create("DivisionByZero", "Can't divide by zero", this))
    end
    return PtlsNumber.create(this.value / other.value):locate(this.loc)
  end;

  this.negate = function(this)
    return PtlsNumber.create(this.value * -1):locate(this.loc)
  end;

  this.getHash = function(this)
    return hash.sha1(tostring(this.value)) .. "IsANumber"
  end;

  this.modded = function(this, other)
    PtlsValue.sameTypes(this, other, PtlsValue.modded)
    return PtlsNumber.create(this.value % other.value):locate(this.loc)
  end;

  this.powed = function(this, other)
    PtlsValue.sameTypes(this, other, PtlsValue.powed)
    return PtlsNumber.create(this.value ^ other.value):locate(this.loc)
  end;

  this.equaled = function(this, other)
    if this.type_ ~= other.type_ then return PtlsBool.create(false) end
    return PtlsBool.create(this.value == other.value):locate(this.loc)
  end;

  this.notEqualed = function(this, other)
    return PtlsBool.create(not (this:equaled(other).value)):locate(this.loc)
  end;

  this.lessThaned = function(this, other)
    PtlsValue.sameTypes(this, other, PtlsValue.lessThaned)
    return PtlsBool.create(this.value < other.value):locate(this.loc)
  end;

  this.lessEqualed = function(this, other)
    PtlsValue.sameTypes(this, other, PtlsValue.lessEqualed)
    return PtlsBool.create(this.value <= other.value):locate(this.loc)
  end;

  this.greaterThaned = function(this, other)
    PtlsValue.sameTypes(this, other, PtlsValue.greaterThaned)
    return PtlsBool.create(this.value > other.value):locate(this.loc)
  end;

  this.greaterEqualed = function(this, other)
    PtlsValue.sameTypes(this, other, PtlsValue.greaterEqualed)
    return PtlsBool.create(this.value >= other.value):locate(this.loc)
  end;

  this.locate = function(this, location)
    this.loc = location
    return this
  end

  this.toString = function(this)
    return tostring(this.value)
  end;

  setmetatable(this, {
    __index = PtlsValue;
    __call = PtlsValueCall;
  })
  return this
end
