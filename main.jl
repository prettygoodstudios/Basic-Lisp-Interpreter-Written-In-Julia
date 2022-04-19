"All tokens conform to this type"
abstract type Token end

"Struct for left parens"
struct LeftParen <: Token
    repr::String
    function LeftParen()
        return new("(")
    end
end

"Struct for right parens"
struct RightParen <: Token
    repr::String
    function RightParen()
        return new(")")
    end
end

"Struct for all identifiers"
struct Identifier <: Token
    repr::String
end

"Struct for all operators"
struct Operator <: Token
    repr::String
end

"Struct for all integer literals"
struct IntegerLiteral <: Token
    repr::String
end

"Struct for all string literals"
struct StringLiteral <: Token
    repr::String
end

"Factory for creating token objects from their string representations"
function tokenFactory(str::String)::Token
    token = match(r"\"(.|\n)*?\"", str)
    if token !== nothing
        return StringLiteral(str)
    end

    token = match(r"quote|defun|if|eq", str)
    if token !== nothing
        return Operator(str)
    end

    token = match(r"[|\-|\+|\/|\*]", str)
    if token !== nothing
        return Operator(str)
    end

    token = match(r"\(", str)
    if token !== nothing
        return LeftParen()
    end

    token = match(r"\)", str)
    if token !== nothing
        return RightParen()
    end

    token = match(r"\d+", str)
    if token !== nothing
        return IntegerLiteral(str)
    end

    token = match(r"\w+", str)
    if token !== nothing
        return Identifier(str)
    end
end

"""
Function that returns first found token and program without first token
"""
function matchToken(program::String)::Tuple{Union{String,Nothing},String}
    token = match(r"(\w+|\d+|\(|\)|\-|\+|\/|\*|\"(.|\n)*?\")|quote|defun|if|eq",program)
    if token === nothing
        return nothing, ""
    end
    return token[1], replace(program, token[1] => "", count=1)
end

"""
Function that retrieves tokens from input program
"""
function getTokens(program::String)::Vector{Token}
    tokens = []
    while length(program) > 0 
        token, program = matchToken(program)
        if token === nothing
            return tokens
        end
        push!(tokens, tokenFactory(token))
    end
    return tokens
end

struct Binding
    parent::Union{Binding,Nothing}
    tokens
    identifiers::Dict{String,Any}
end

"""
Function that builds initial tree
"""
function buildTree(tokens::Vector{Token})
    tree = Binding(nothing, [], Dict())
    current = tree
    leftParen = LeftParen()
    rightParen = RightParen()
    for token in tokens
        oldCurrent = current
        if token === leftParen
            current = Binding(oldCurrent, [], Dict())
            push!(oldCurrent.tokens, current)
        elseif token === rightParen
            current = oldCurrent.parent
        else
            push!(oldCurrent.tokens, token)
        end
    end
    tree
end

"""
Function that prints out parseTree 
"""
function printParseTree(tree::Binding, depth::Int=0)
    tabs = "\t" ^ depth
    println(tabs * "(")
    for token in tree.tokens 
        if typeof(token) === Binding
            printParseTree(token, depth+1)
        end
        if typeof(token) <: Token
            println(tabs * "\t" * token.repr)
        end
    end
    println(tabs * ")")
end

"""
Determine if a binding is a function
"""
function isFunction(x::Union{Token, Binding})::Bool
    if typeof(x) === Binding
        return x.tokens[1] === Operator("defun")
    end
    return false
end

"""
Determine if a binding is a function call
"""
function isFunctionCall(x::Union{Token, Binding})::Bool
    return typeof(x) === Binding && typeof(x.tokens[1]) === Identifier
end

"""
Determine if a binding is a expression with a operator
"""
function isOperatorExpression(x::Union{Token, Binding})
    if typeof(x) === Binding
        return x.tokens[1] !== Operator("defun") && typeof(x.tokens[1]) === Operator
    end
    return false
end

"""
Looks up identifier in bindings
"""
function lookupIdentifier(tree::Union{Binding,Nothing}, identifier::String)
    if tree === nothing
        return nothing
    end
    if haskey(tree.identifiers, identifier)
        return tree.identifiers[identifier]
    end
    return lookupIdentifier(tree.parent, identifier)
end

"""
Evaluates program
"""
function evalProgram(tree::Union{Binding,Token}, parent::Binding)::Union{String, Int32, Bool}
    if typeof(tree) === StringLiteral
        return tree.repr
    end
    if typeof(tree) === IntegerLiteral
        return parse(Int32, tree.repr)
    end
    if typeof(tree) === Identifier
        identifier = lookupIdentifier(parent, tree.repr)
        if identifier === nothing
            throw(ErrorException("Identifier is not defined."))
        end
        return evalProgram(identifier, parent)
    end
    if isFunction(tree)
        return evalProgram(tree.tokens[4], tree)
    end
    if isOperatorExpression(tree)
        operator = tree.tokens[1].repr
        if operator === "+"
            return evalProgram(tree.tokens[2], tree) + evalProgram(tree.tokens[3], tree)
        elseif operator === "-"
            return evalProgram(tree.tokens[2], tree) - evalProgram(tree.tokens[3], tree)
        elseif operator === "*"
            return evalProgram(tree.tokens[2], tree) * evalProgram(tree.tokens[3], tree)
        elseif operator === "/"
            return evalProgram(tree.tokens[2], tree) / evalProgram(tree.tokens[3], tree)
        elseif operator === "if"
            if evalProgram(tree.tokens[2], tree)
                return evalProgram(tree.tokens[3], tree)
            elseif size(tree.tokens) === (4,)
                return evalProgram(tree.tokens[4], tree)
            end
        elseif operator === "eq"
            return evalProgram(tree.tokens[2], tree) === evalProgram(tree.tokens[3], tree)
        end
    end
    if isFunctionCall(tree)
        functionName = tree.tokens[1].repr
        functionCode = deepcopy(lookupIdentifier(tree, functionName))
        for (name, value) in zip(functionCode.tokens[3].tokens, tree.tokens[2].tokens)
            functionCode.identifiers[name.repr] = value
        end
        evalProgram(functionCode.tokens[4], functionCode)
    end
end

"""
Runs program
"""
function runProgram(tree::Binding)
    # Find functions
    functions = filter(isFunction, tree.tokens)
    for f in functions
        tree.identifiers[f.tokens[2].repr] = f
    end
    println(keys(tree.identifiers))
    for line in filter(x -> !isFunction(x), tree.tokens)
        println(evalProgram(line, tree))
    end
end