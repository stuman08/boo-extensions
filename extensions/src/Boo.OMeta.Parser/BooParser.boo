namespace Boo.OMeta.Parser

import Boo.Lang.Compiler.Ast
import Boo.OMeta

ometa BooParser < WhitespaceSensitiveTokenizer:
	
	tokens:
		eq = "="
		num = ++digit
		id = (letter | '_'), --(letter | digit | '_')
		colon = ":"
		dot = "."
		comma = ","
		lparen = "("
		rparen = ")"
		kw = (keywords >> value, ~(letter | digit)) ^ value
		
	keywords "class", "def", "import", "pass", "return"
	
	keyword[expected] = ((KW >> t) and (expected is tokenValue(t))) ^ t
	
	module = (
		--whitespace,
		--importDeclaration >> ids,
		--classDef >> types,
		--stmt >> stmts,
		--whitespace
	) ^ newModule(ids, types, stmts)
	
	importDeclaration = (IMPORT, qualifiedName >> ns, eol) ^ newImport(ns)
	
	qualifiedName = (ID >> qualifier, --((DOT, ID >> n) ^ n) >> suffix)^ buildQName(qualifier, suffix) 
	
	classDef = (
		CLASS, ID >> className, beginBlock, classBody >> body, endBlock
	) ^ newClass(className, body)
	
	beginBlock = COLON, INDENT
	
	endBlock = DEDENT
	
	classBody = ((PASS, eol) ^ null) | (++classMember >> members ^ members)
	
	classMember = method | classDef
	
	method = (
		DEF, ID >> name, LPAREN, RPAREN, beginBlock, methodBody >> body, endBlock
	) ^ newMethod(name, body)
	
	methodBody = ++stmt >> stmts ^ newBlock(stmts)
	
	stmt = (stmtLine >> s, eol) ^ s
	
	stmtLine = stmtExpression | stmtReturn
	
	stmtReturn = (
		((RETURN, expression >> e) ^ ReturnStatement(Expression: e))
		| (RETURN ^ ReturnStatement())
	) 

	stmtExpression = expression >> e ^ ExpressionStatement(Expression: e)
	
	expression = assign | invocation | rvalue
	
	expressionList = (expression >> first, --(COMMA, expression) >> rest) ^ prepend(first, rest)
	
	invocation = (rvalue >> target, LPAREN, expressionList >> args, RPAREN) ^ newInvocation(target, args)
	
	assign = (lvalue >> l, EQ, expression >> r) ^ newAssignment(l, r)
	
	lvalue = ID >> r ^ newReference(r)
	
	rvalue = integer | lvalue
	
	integer = NUM >> n ^ newInteger(n)
	
	eol = ++EOL | ~_	
	
	def newModule(imports, members, stmts):
		m = Module()
		for item in imports: m.Imports.Add(item)
		for member in members: m.Members.Add(member)
		for stmt as Statement in stmts: m.Globals.Add(stmt)
		return m
		
	def newImport(qname as string):
		return Import(Namespace: qname)
	
	def newInteger(t):
		return IntegerLiteralExpression(Value: int.Parse(tokenValue(t)))
		
	def newMethod(name, body as Block):
		return Method(Name: tokenValue(name), Body: body)
		
	def newClass(name, members):
		klass = ClassDefinition(Name: tokenValue(name))
		if members is not null: 
			for member in members: klass.Members.Add(member)
		return klass
		
	def newInvocation(target as Expression, args as List):
		mie = MethodInvocationExpression(Target: target)
		for arg in args: mie.Arguments.Add(arg)
		return mie
		
	def newReference(t):
		return ReferenceExpression(Name: tokenValue(t))
		
	def newAssignment(l as Expression, r as Expression):
		return [| $l = $r |]
		
	def newBlock(stmts):
		block = Block()
		for item in stmts:
			block.Statements.Add(item)
		return block
		
	def prepend(first, tail as List):
		tail.Insert(0, first)
		return tail
		
	def buildQName(q, rest):
		return join(tokenValue(t) for t in prepend(q, rest), '.')
