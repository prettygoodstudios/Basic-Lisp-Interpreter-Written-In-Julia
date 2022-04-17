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
    token = match(r"\".*\"", str)
    if token !== nothing
        return StringLiteral(str)
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
    token = match(r"(\w+|\d+|\(|\)|\-|\+|\/|\*|\".*\")",program)
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
    program = replace(program, "\n" => "")
    while length(program) > 0 
        token, program = matchToken(program)
        if token === nothing
            return tokens
        end
        push!(tokens, tokenFactory(token))
    end
    return tokens
end