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

    token = match(r"quote", str)
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
    token = match(r"(\w+|\d+|\(|\)|\-|\+|\/|\*|\"(.|\n)*?\")|quote",program)
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
end

"""
Function that builds parse tree
"""
function buildParseTree(tokens::Vector{Token})
    tree = Binding(nothing, [])
    current = tree
    leftParen = LeftParen()
    rightParen = RightParen()
    for token in tokens
        oldCurrent = current
        if token === leftParen
            current = Binding(oldCurrent, [])
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
function printParseTree(tree, depth=0)
    if tree === nothing
        return
    end
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