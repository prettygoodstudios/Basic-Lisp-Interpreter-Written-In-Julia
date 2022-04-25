abstract type AbstractSyntaxTreeToken end

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
    identifiers::Dict{AbstractString,Union{PrimitiveType,AbstractSyntaxTreeToken}}
end

"Recursively looksup identifier in bindings"
function lookupInBinding(binding::Union{Binding,Nothing}, name::AbstractString)::Union{AbstractSyntaxTreeToken,Nothing}
    if binding === nothing
        throw(ErrorException("$name is not defined."))
    end
    if name in keys(binding.identifiers)
        return binding.identifiers[name]
    end
    return lookupInBinding(binding.parent, name)
end

struct FunctionDefinition <: AbstractSyntaxTreeToken
    children::Vector{AbstractSyntaxTreeToken}
    text::AbstractString
    eval::Function
    function FunctionDefinition()
        return new([], "", function (this::FunctionDefinition, binding::Binding)
            functionBody = last(this.children)
            functionBody.eval(functionBody, binding)
        end)
    end
end

struct Operator <: AbstractSyntaxTreeToken
    children::Vector{AbstractSyntaxTreeToken}
    text::AbstractString
    eval::Function
    function Operator(text::AbstractString, operator::Function)
        return new([], text, (this::Operator, binding::Binding) -> operator(map(x -> x.eval(x, binding), this.children)...))
    end
end

struct Literal <: AbstractSyntaxTreeToken
    children::Vector{AbstractSyntaxTreeToken}
    text::AbstractString
    eval::Function
    function Literal(text::AbstractString, value::PrimitiveType)
        return new([], text, (this::Literal, binding::Binding) -> value)
    end
end

struct Identifier <: AbstractSyntaxTreeToken
    children::Vector{AbstractSyntaxTreeToken}
    text::AbstractString
    eval::Function
    function Identifier(text::AbstractString)
        return new([], text, function (this::Identifier, binding::Binding)
            token = lookupInBinding(binding, this.text)
            if typeof(token) === FunctionDefinition
                newBinding = Binding(binding, Dict())
                if size(token.children)[1] > 2
                    variableNames = map(x -> x.text, [token.children[2], token.children[2].children...])
                    for (name, value) in zip(variableNames, this.children)
                        value = Literal("Cached result", value.eval(value, binding))
                        newBinding.identifiers[name] = value
                    end
                end
                return token.eval(token, newBinding)
            end
            return token.eval(token, binding)
        end)
    end
end

matchers = [
    Matcher("\"(.|\n)*?\"", (text::AbstractString) -> Literal(text, text)),
    Matcher("defun", (text::AbstractString) -> FunctionDefinition()),
    Matcher("eq", (text::AbstractString) -> Operator(text, ==)),
    Matcher("if", (text::AbstractString) -> Operator(text, function(rest...)
        if rest[1]
            return rest[2]
        end
        if length(rest) > 2
            return rest[3]
        end
        return nothing
    end)),
    Matcher("(\\(|\\))", (text::AbstractString) -> Paren(text)),
    Matcher("\\d+", (text::AbstractString)  -> Literal(text, parse(Int32, text))),
    Matcher("\\w+", (text::AbstractString) -> Identifier(text)),
    Matcher("\\*", (text::AbstractString) -> Operator(text, *)),
    Matcher("\\+", (text::AbstractString) -> Operator(text, +)),
    Matcher("\\-", (text::AbstractString) -> Operator(text, -)),
    Matcher("\\/", (text::AbstractString) -> Operator(text, /)),
]

"Generates tokens"
function getTokens(sourceCode::AbstractString, matchers::Vector{Matcher})::Vector{Union{Paren, AbstractSyntaxTreeToken}}
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

"Recursively build abstract syntax tree"
function buildAbstractSyntaxTree(tokens::Vector{Union{Paren, AbstractSyntaxTreeToken}}, parent)
    while size(tokens)[1] > 0
        token = popfirst!(tokens)
        if token.text == "("
            token = popfirst!(tokens)
            if !(token.text in Set(["(", ")"]))
                push!(parent, token)
                buildAbstractSyntaxTree(tokens, token.children)
            end
        elseif token.text == ")"
            return parent
        else
            push!(parent, token)
        end
    end
    parent
end

"Takes tokens from program and produces abstract syntax trees"
function buildAbstractSyntaxTrees(tokens::Vector{Union{Paren, AbstractSyntaxTreeToken}})::Vector{AbstractSyntaxTreeToken}
    return buildAbstractSyntaxTree(tokens, [])
end

function runProgram(sourceCode::AbstractString, matchers::Vector{Matcher})
    tokens = getTokens(sourceCode, matchers)
    trees = buildAbstractSyntaxTrees(tokens)
    binding = Binding(nothing, Dict())
    for tree in filter(x -> typeof(x) === FunctionDefinition, trees)
        binding.identifiers[tree.children[1].text] = tree
    end
    println(keys(binding.identifiers))
    trees = filter(x -> typeof(x) !== FunctionDefinition, trees)
    for tree in trees
        println(tree.eval(tree, binding))
    end
end

runProgram("(defun fib (n blah) (+ 1 3))(+ (- 5 4) 3)(- (- 5 (+ 8 9)) (* 7 5))", matchers)
runProgram("(defun fib () (+ 1 3))(fib ())", matchers)
runProgram("(defun fib (n) (+ n 3))(fib 10)", matchers)
runProgram("(eq 1 1)(eq 2 3)(if (eq 1 1) 1 3)(if (eq 1 2) 1 3)", matchers)
runProgram("(defun fac (n) (if (eq n 0) 1 (fac (- n 1))))(fac 3)", matchers)
