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
struct Indentifier <: Token
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
        return Indentifier(str)
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
    indentifiers::Dict{String,Any}
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
Determine if a binding is a expression with a operator
"""
function isOperatorExpression(x::Union{Token, Binding})
    if typeof(x) === Binding
        return x.tokens[1] !== Operator("defun") && typeof(x.tokens[1]) === Operator
    end
    return false
end
"""
Evaluates program
"""
function evalProgram(tree::Union{Binding,Token})
    if typeof(tree) === StringLiteral
        return tree.repr
    end
    if typeof(tree) === IntegerLiteral
        return parse(Int32, tree.repr)
    end
    if typeof(tree) === Binding && isFunction(tree)
        return evalProgram(tree.tokens[4])
    end
    if typeof(tree) === Binding && isOperatorExpression(tree)
        operator = tree.tokens[1].repr
        if operator === "+"
            return evalProgram(tree.tokens[2]) + evalProgram(tree.tokens[3])
        elseif operator === "-"
            return evalProgram(tree.tokens[2]) - evalProgram(tree.tokens[3])
        elseif operator === "*"
            return evalProgram(tree.tokens[2]) * evalProgram(tree.tokens[3])
        elseif operator === "/"
            return evalProgram(tree.tokens[2]) / evalProgram(tree.tokens[3])
        elseif operator === "if"
            if evalProgram(tree.tokens[2])
                return evalProgram(tree.tokens[3])
            elseif count(tree.tokens) === 4
                return evalProgram(tree.tokens[4])
            end
        elseif operator === "eq"
            return evalProgram(tree.tokens[2]) === evalProgram(tree.tokens[3])
        end
    end
end

"""
Runs program
"""
function runProgram(tree::Binding)
    # Find functions
    functions = filter(isFunction, tree.tokens)
    for f in functions
        tree.identifiers[f.tokens[1].repr] = f
    end
    println(keys(tree.indentifiers))
    for line in filter(x -> !isFunction(x), tree.tokens)
        println(evalProgram(line))
    end
end