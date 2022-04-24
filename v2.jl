abstract type AbstractSourceTreeToken end

PrimitiveType = Union{AbstractString, Int32, Bool, Vector}

struct Paren
    text::AbstractString
end

"Stores regex to match a token and the function to create a token of that type"
struct Matcher
    matcher::AbstractString
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
        return new([], text, (this::Operator) -> operator(this.children[1].eval(this.children[1]), this.children[2].eval(this.children[2])))
    end
end

struct Literal <: AbstractSourceTreeToken
    children::Vector{AbstractSourceTreeToken}
    text::AbstractString
    eval::Function
    function Literal(text::AbstractString, value::PrimitiveType)
        return new([], text, (this::Literal) -> value)
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
    Matcher("\"(.|\n)*?\"", (text::AbstractString) -> Literal(text, text)),
    Matcher("(\\(|\\))", (text::AbstractString) -> Paren(text)),
    Matcher("\\d+", (text::AbstractString)  -> Literal(text, parse(Int32, text))),
    Matcher("\\w+", (text::AbstractString) -> Identifier(text)),
    Matcher("\\*", (text::AbstractString) -> Operator(text, *)),
    Matcher("\\+", (text::AbstractString) -> Operator(text, +)),
    Matcher("\\-", (text::AbstractString) -> Operator(text, -)),
    Matcher("\\/", (text::AbstractString) -> Operator(text, /)),
]

"Generates tokens"
function getTokens(sourceCode::AbstractString, matchers::Vector{Matcher})::Vector{Union{Paren, AbstractSourceTreeToken}}
    tokens = []
    tokenRegex = Regex(join(map(x -> x.matcher, matchers),"|"))
    while length(sourceCode) > 0
        token = match(tokenRegex, sourceCode)
        if token !== nothing
            sourceCode = replace(sourceCode, token.match => "", count=1)
            sourceCode = rstrip(sourceCode)
            for matcher in matchers
                found = match(Regex(matcher.matcher), token.match)
                if found !== nothing
                    push!(tokens, matcher.tokenFactory(token.match))
                    break
                end
            end
        end
    end
    tokens
end

"Recursively build abstract source tree"
function buildAbstractSourceTree(tokens::Vector{Union{Paren, AbstractSourceTreeToken}}, parent)
    while size(tokens)[1] > 0
        token = popfirst!(tokens)
        if token.text == "("
            token = popfirst!(tokens)
            push!(parent, token)
            buildAbstractSourceTree(tokens, token.children)
        elseif token.text == ")"
            return parent
        else
            push!(parent, token)
        end
    end
    parent
end

"Takes tokens from program and produces abstract source trees"
function buildAbstractSourceTrees(tokens::Vector{Union{Paren, AbstractSourceTreeToken}})::Vector{AbstractSourceTreeToken}
    return buildAbstractSourceTree(tokens, [])
end

function runProgram(sourceCode::AbstractString, matchers::Vector{Matcher})
    tokens = getTokens(sourceCode, matchers)
    trees = buildAbstractSourceTrees(tokens)
    for tree in trees
        println(tree.eval(tree))
    end
end

runProgram("(+ (- 5 4) 3)", matchers)
runProgram("(- (- 5 (+ 8 9)) (* 7 5))", matchers)
