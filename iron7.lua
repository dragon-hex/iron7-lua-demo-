-------------------------------------------------------------------------------
function unpackt(t)
	assert(type(t)==type({}),"expected string, got: "..type(s))
	local s="" for i,v in ipairs(t) do s=string.format("%s\n[%d]: %s",s,i,v) end
	return s
end
-------------------------------------------------------------------------------
I7={}
-------------------------------------------------------------------------------
I7.STokens={
	['+']=true,['-']=true,['*']=true,['/']=true,
	['<']=true,['>']=true,['=']=true,[',']=true,
	['[']=true,[']']=true,['(']=true,[')']=true
}
I7.DTokens={
	['==']=true,['!=']=true,['<=']=true,['>=']=true,
	['{}']=true,['()']=true,
}
-------------------------------------------------------------------------------
function I7:lex(s)
	assert(type(s)==type(""),"expected string, got: "..type(s))
	local s,Acc,Tokens=(s..' '),"",{}
	local InString,InStringChar=false,''
	local CharIndex=1
	local function DoInsert()
		if #Acc>0 then
			table.insert(Tokens,Acc)
		end
		Acc=""
	end
	local function OpenString(Char)
		DoInsert()
		Acc,InString,InStringChar=Char,true,Char
	end
	local function CloseString()
		table.insert(Tokens,Acc..InStringChar)
		Acc,InString="",false
	end
	while CharIndex<=#s do
		local Char=s:sub(CharIndex,CharIndex)
		local NextChar=(CharIndex<=#s)and(s:sub(CharIndex+1,CharIndex+1))or(' ')
		if Char==' ' and not InString then DoInsert() CharIndex=CharIndex+1
		elseif (Char=='-' and NextChar=='-') and not InString then DoInsert() break
		elseif (Char=='"' or Char=="'") and not InString then OpenString(Char) CharIndex=CharIndex+1
		elseif (Char=='"' or Char=="'") and     InString and Char==InStringChar then CloseString() CharIndex=CharIndex+1
		else Acc,CharIndex=Acc..Char,CharIndex+1 end
	end
	return Tokens
end
-------------------------------------------------------------------------------
local CodeLine="function() print('hello world!') end"
print(unpackt(I7:lex(CodeLine)))
