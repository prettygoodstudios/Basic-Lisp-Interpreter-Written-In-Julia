abstract type AbstractSourceTreeToken end

PrimitiveType = Union{AbstractString, Int32, Bool, Vector}

struct Paren
    text::AbstractString
end

"Stores regex to match a token and the function to create a token of that type"
struct Matcher
    matcher::Regex
    tokenFactory::Function
end

struct Binding
    parent::Union{Binding,Nothing}
    identifiers::Dict{AbstractString,Union{PrimitiveType,AbstractSourceTreeToken}}
end

struct Operator <: AbstractSourceTreeToken
    children::Vector{AbstractSourceTreeToken}
    text::AbstractString
    eval::Function
    function Operator(text::AbstractString, operator::Function)
        return new([], text, () -> operator(children[1].eval(), children[2].eval()))
    end
end

struct Literal <: AbstractSourceTreeToken
    children::Vector{AbstractSourceTreeToken}
    text::AbstractString
    eval::Function
    function Literal(text::AbstractString, value::PrimitiveType)
        return new([], text, () -> value)
    end
end

struct Identifier <: AbstractSourceTreeToken
    children::Vector{AbstractSourceTreeToken}
    text::AbstractString
    function Identifier(text::AbstractString)
        return new([], text)
    end
end

matchers = [
    Matcher(r"\"(.|\n)*?\"", (text::AbstractString) -> Literal(text, text)),
    Matcher(r"\d+", (text::AbstractString)  -> Literal(text, parse(Int32, text))),
    Matcher(r"\(|\)", (text::AbstractString) -> Paren(text)),
    Matcher(r"\w+", (text::AbstractString) -> Identifier(text)),
    Matcher(r"\*", (text::AbstractString) -> Operator(text, *)),
    Matcher(r"\+", (text::AbstractString) -> Operator(text, +)),
    Matcher(r"\-", (text::AbstractString) -> Operator(text, -)),
    Matcher(r"\/", (text::AbstractString) -> Operator(text, /)),
]

"Generates tokens"
function getTokens(sourceCode::String, matchers::Vector{Matcher})::Vector{Union{Paren, AbstractSourceTreeToken}}
    tokens = []
    for matcher in matchers
        token = match(matcher.matcher, sourceCode)
        if token !== nothing
            sourceCode = replace(sourceCode, token.match => "", count=1)
            print(matcher)
            push!(tokens, matcher.tokenFactory(token.match))
        end
    end
    tokens
end

"Recursively build abstract source tree"
function buildAbstractSourceTree(tokens::Vector{Union{Paren, AbstractSourceTreeToken}}, parent)
    while size(tokens)[1] > 0
        token = pop!(tokens)
        if token === Paren("(")
            token = pop!(tokens)
            push!(buildAbstractSourceTree(tokens, token.children))
        elseif token === Paren(")")
            return parent
        else
            push!(parent, token)
        end
    end
    parent
end

function buildAbstractSourceTree(tokens::Vector{Union{Paren, AbstractSourceTreeToken}})
    return buildAbstractSourceTree(tokens, [])
end

testOne = buildAbstractSourceTree(getTokens("(+ (- 5 4) 3)", matchers))
testTwo = buildAbstractSourceTree(getTokens("(- (- 5 (+ 8 9)) (* 7 5))", matchers))
println(testOne)
println(testTwo)
