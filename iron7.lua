-------------------------------------------------------------------------------
-- s7: complex of compiler and bytecode generation
-------------------------------------------------------------------------------
local args={...}
-------------------------------------------------------------------------------
local tinsert=table.insert
local tremove=table.remove
local sformat=string.format
local sbyte=string.byte 
local outputIdx,outputEn=0,args[1]=='-d'
local output=function(...)
  if not outputEn then return end
  local s=sformat("[Core=%08x] ",outputIdx)..sformat(...)
  io.write(s)
  outputIdx=outputIdx+1
end
------------------------------------------------------------------------------
local unpackt=function(t)
  assert(type(t)==type({}),"expected table, got: "..type(t))
  local s="" for index,value in ipairs(t) do output(sformat("%s[unpackt=%08d]: %s\n",s,index,value)) end
  return s
end
------------------------------------------------------------------------------
s7={}
------------------------------------------------------------------------------
s7.STokens={
	['+']=true,['-']=true,['*']=true,['/']=true,
	['<']=true,['>']=true,['=']=true,[',']=true,
	['[']=true,[']']=true,['(']=true,[')']=true,
  ['{']=true,['}']=true,
  [':']=true,
}
s7.DTokens={
	['==']=true,['!=']=true,['<=']=true,['>=']=true,
	['()']=true,
}
s7.Keyword={
  ["if"]=true,      ["else"]=true,  ["elif"]=true,
  ["while"]=true,   ["for"]=true,
  ["define"]=true,  ["name"]=true
}
-------------------------------------------------------------------------------
function s7:IsValidName(s, ConsiderPoint)
  assert(type(s)==type(""),"expected string, got: "..type(s))
  local function IsValidChar(Char,Num)
    return(sbyte(Char)>=sbyte('A') and sbyte(Char)<=sbyte('Z')) or
          (sbyte(Char)>=sbyte('a') and sbyte(Char)<=sbyte('z')) or
          (sbyte(Char)>=sbyte('0') and sbyte(Char)<=sbyte('9') and Num) or
          (Char == '_') or
          (Char == '.' and ConsiderPoint)
  end
  for Index=1,#s do
    if not IsValidChar(s:sub(Index,Index),Index>1) then return false end
  end
  return true
end
-------------------------------------------------------------------------------
function s7:Parse(s)
	assert(type(s)==type(""),"expected string, got: "..type(s))
	local s,Acc,Tokens=(s..' '),"",{}
	local InString,InStringChar=false,''
	local CharIndex,Char,NextChar=1,' ',' '
	local function DoInsert()
		if #Acc>0 then
			tinsert(Tokens,Acc)
		end
		Acc=""
	end
	local function OpenString()
		DoInsert()
		Acc,InString,InStringChar=Char,true,Char
	end
	local function CloseString()
		tinsert(Tokens,Acc..InStringChar)
		Acc,InString="",false
	end
	while CharIndex<=#s do
		Char=s:sub(CharIndex,CharIndex)
		NextChar=(CharIndex<=#s)and(s:sub(CharIndex+1,CharIndex+1))or(' ')
		if Char==' ' and not InString then 
      DoInsert() 
      CharIndex=CharIndex+1
		elseif (Char=='-' and NextChar=='-') and not InString then 
      DoInsert() 
      break
		elseif (Char=='"' or Char=="'") and not InString then 
      OpenString()
      CharIndex=CharIndex+1
		elseif (Char=='"' or Char=="'") and InString and Char==InStringChar then 
      CloseString() 
      CharIndex=CharIndex+1
    elseif (s7.STokens[Char]~=nil or s7.DTokens[Char..NextChar]~=nil) and not InString then
      DoInsert()
      local DoMerge=s7.DTokens[Char..NextChar]
      tinsert(Tokens,DoMerge and (Char..NextChar) or Char)
      CharIndex=CharIndex+(DoMerge and 2 or 1)
		else 
      Acc,CharIndex=Acc..Char,CharIndex+1 
    end
	end
	return Tokens
end
-------------------------------------------------------------------------------
function s7:NewLexState()
  return {
    -- iron7 is class oriented, so, mount an element for the class
    -- also, iron7 has the function callable by special groups (names)
    -- just like in C++
    functions={main={}},
    objects={},

    -- Save the state of the compiler until the next line
    atFunction={"main"},
    
    -- just dummy for test if LexState
    isLexState=true
  }
end
-------------------------------------------------------------------------------
function s7:DebugShowLexTree(tree)
  assert(type(tree)==type({}),"expected table, got: "..type(tree))
  assert(tree['isLexState']~=nil,"tree should be LexState")
  for fname, fbody in pairs(tree.functions) do
    output(sformat("function: %s",fname)..'\n')
    for argn, argt in pairs(fbody.args) do
      output(sformat("Argument Variable [%s] is type: %s", argn, argt)..'\n')
    end
    for index, code in ipairs(fbody.code) do
      output(sformat("token at [%04d]: %s\n",index,code))
    end
  end
  for oname, obody in pairs(tree.objects) do
    output(sformat("object: %s , type: %s", oname, obody) .. '\n')
  end
end
-------------------------------------------------------------------------------
function s7:Lex(LexState,s)
  assert(type(s)==type(""),"expected string, got: "..type(s))
  local Parsed,ParserCounter=s7:Parse(s),1
  unpackt(Parsed)
  while ParserCounter<=#Parsed do
    local Token=Parsed[ParserCounter]
    if Token=="function" then
      assert(ParserCounter+3<=#Parsed,"incomplete function declaration")
      assert(s7:IsValidName(Parsed[ParserCounter+1],true),sformat("invalid name for function: %s",Parsed[ParserCounter+1]))
      assert(Parsed[ParserCounter+2]=='(' or Parsed[ParserCounter+2]=='()', sformat("invalid function argument at: %s",Parsed[ParserCounter+1]))
      local Fname,Fargs=Parsed[ParserCounter+1],{}
      if #LexState.atFunction > 1 then
        local GenericName=""
        -- collapse all the top name on the stack
        for key, data in ipairs(LexState.atFunction) do
          GenericName=data..'.'
        end
        Fname=GenericName..Fname
      end
      output(sformat("begin function building for: %s",Fname).. '\n')
      if Parsed[ParserCounter+2]=='(' then
        -- begin to parse the argument list data, the arguments are organized
        -- after the token ',' so, it is: main (myString, cubex:number)
        local PostCounter=ParserCounter+3
        local AgName=""
        while PostCounter<=#Parsed do
          local TokenArg=Parsed[PostCounter]
          output(sformat("Post Counter: %d is %s",PostCounter,TokenArg))
          if TokenArg==',' then
            -- ignore this ',' since this token is just used
            -- for organize the list.
            PostCounter=PostCounter+1
          elseif TokenArg==')' then
            break
          else
            output("on loading function " .. TokenArg .. ", in array: " .. tostring(Fargs[TokenArg]) .. '\n')
            assert(s7:IsValidName(TokenArg),sformat("invalid argument name: %s",TokenArg))
            assert(Fargs[TokenArg]==nil,"duplicated function argument")
            local AgType=nil
            if PostCounter+2<=#Parsed then
              -- does the token ':' is present, if is, then
              -- try to select.
              if Parsed[PostCounter+1]==':' then
                -- assume by the name if is not an token or an keyword
                assert(s7:IsValidName(Parsed[PostCounter+2],true),sformat("invalid argument type: %s",Parsed[PostCounter+2]))
                AgType=Parsed[PostCounter+2]
              end
            end
            AgName=Parsed[PostCounter]
            Fargs[AgName]=(AgType==nil)and('dynamic')or(AgType)
            PostCounter=PostCounter+((AgType==nil) and 1 or 3)
          end
          output(Parsed[PostCounter].. '\n')
        end
        --until #Parsed>=PostCounter
        assert(Parsed[PostCounter]==')',sformat("not closed function argument list for: %s",Fname))
        ParserCounter=PostCounter
      elseif Parsed[ParserCounter+2]=='()' then
        ParserCounter=ParserCounter+2
      end
      -- increment for finish the function parsing
      ParserCounter=ParserCounter+1
      -- built the function, assert on the next there '{' to open
      -- an new function, if not, then the syntax is wrong.
      assert(Parsed[ParserCounter]=='{',sformat("expected token: '{' for open function: %s",Fname))
      -- build the new function, if the name of the function main() wasn't set yet, then
      -- set on the stack for this function.
      assert(
        (LexState.functions[Fname] == nil) or
        (Fname=='main' and LexState.functions[Fname]['code']==nil),
        sformat("duplicated function name: %s",Fname)
      )
      -- finalize the function building.
      LexState.functions[Fname]={args={},code={}}
      for argName,argType in pairs(Fargs) do LexState.functions[Fname].args[argName]=argType end
      -- we inside an function, up on the stack
      tinsert(LexState.atFunction,Fname)
      ParserCounter=ParserCounter+1
    elseif Token=="name" then
      -- an namespace is an object then, store on the objects
      assert(ParserCounter+1<=#Parsed,"incomplete namespace definition.")
      LexState.objects[Token]=Parsed[ParserCounter+1]
      ParserCounter=ParserCounter+2
    elseif Token=='}' then
      -- pop from stack an value
      assert(#LexState.atFunction>0,"invalid function finalization")
      tremove(LexState.atFunction,#LexState.atFunction-1)
      ParserCounter=ParserCounter+1
    else
      -- since we not compiling any instruction yet, just organizing the code
      -- we put the token on the function code.
      local atFunction=LexState.atFunction[#LexState.atFunction]
      table.insert(LexState.functions[atFunction].code,Token)
      ParserCounter=ParserCounter+1
    end
  end
end
-------------------------------------------------------------------------------
local L_State=s7:NewLexState()
local tree=s7:Lex(L_State,"name game function main(player:game.Player,listSize: number){ print('Hello World!') }")
s7:Lex(L_State,"function game.stop() { function system () {} print('stopped') }")
--s7:DebugShowLexTree(L_State)
