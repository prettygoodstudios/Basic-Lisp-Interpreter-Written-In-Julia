abstract type AbstractSourceTreeToken end

PrimitiveType = Union{AbstractString, Int32, Bool, Vector}

struct Paren
    text::AbstractString
end

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
        return new([], text, (evalToken) -> operator(evalToken(children[1]), evalToken(children[2])))
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
    text::AbstractString
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