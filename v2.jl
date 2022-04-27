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
        return new([], text, (this::Operator, binding::Binding) -> operator(this.children, child -> child.eval(child, binding)))
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
            if isa(token, FunctionDefinition)
                newBinding = Binding(binding, Dict())
                if length(token.children) > 2
                    variableNames = map(x -> x.text, [token.children[2], token.children[2].children...])
                    for (name, value) in zip(variableNames, this.children)
                        if isa(value, Identifier)
                            value = lookupInBinding(binding, value.text)
                        end
                        # If it can be evaluated, evaluate it
                        # Functions and operators cannot be directly evaluated
                        if !isa(value, FunctionDefinition) && (!isa(value, Operator) || length(value.children) !== 0)
                            value = Literal("Cached result", value.eval(value, binding))
                        end
                        newBinding.identifiers[name] = value
                    end
                end
                return token.eval(token, newBinding)
            end
            empty!(token.children)
            push!(token.children, this.children...)
            return token.eval(token, binding)
        end)
    end
end

matchers = [
    Matcher("\"(.|\n)*?\"", (text::AbstractString) -> Literal(text, text[2:length(text)-1])),
    Matcher("defun", (text::AbstractString) -> FunctionDefinition()),
    Matcher("eq", (text::AbstractString) -> Operator(text, (children, eval) -> eval(children[1]) == eval(children[2]))),
    Matcher("if", (text::AbstractString) -> Operator(text, function(children,eval)
        if eval(children[1])
            return eval(children[2])
        end
        if length(children) > 2
            return eval(children[3])
        end
        return nothing
    end)),
    Matcher("quote", (text::AbstractString) -> Operator(text, function (children, eval)
        if length(children) > 0
            return [eval(children[1]), map(x -> eval(x), children[1].children)...]
        end
        map(x -> eval(x), children)
    end)),
    Matcher("nil", (text::AbstractString) -> Literal("nil", [])),
    Matcher("cons", (text::AbstractString) -> Operator("cons", (children, eval) -> [eval(children[1])..., eval(children[2])...])),
    Matcher("first", (text::AbstractString) -> Operator("first", (children, eval) -> first(eval(children[1])))),
    Matcher("rest", (text::AbstractString) -> Operator("rest", function (children, eval) 
        l = eval(children[1])
        l[2:length(l)]
    end)),
    Matcher("index", (text::AbstractString) -> Operator("index", (children, eval) -> eval(children[1])[eval(children[2])])),
    Matcher("true", (text::AbstractString) -> Literal("true", true)),
    Matcher("false", (text::AbstractString) -> Literal("false", false)),
    Matcher("\\&\\&", (text::AbstractString) -> Operator("&&", (children, eval) -> eval(children[1]) && eval(children[2]))),
    Matcher("\\|\\|", (text::AbstractString) -> Operator("||", (children, eval) -> eval(children[1]) || eval(children[2]))),
    Matcher("\\!", (text::AbstractString) -> Operator("!", (children, eval) -> !eval(children[1]))),
    Matcher("(\\(|\\))", (text::AbstractString) -> Paren(text)),
    Matcher("\\d+", (text::AbstractString)  -> Literal(text, parse(Int32, text))),
    Matcher("\\w+", (text::AbstractString) -> Identifier(text)),
    Matcher("\\*", (text::AbstractString) -> Operator(text, (children, eval) -> eval(children[1]) * eval(children[2]))),
    Matcher("\\+", (text::AbstractString) -> Operator(text, (children, eval) -> eval(children[1]) + eval(children[2]))),
    Matcher("\\-", (text::AbstractString) -> Operator(text, (children, eval) -> eval(children[1]) - eval(children[2]))),
    Matcher("\\/", (text::AbstractString) -> Operator(text, (children, eval) -> eval(children[1]) / eval(children[2]))),
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
    while length(tokens) > 0
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

function runProgram(sourceCode::AbstractString, matchers::Vector{Matcher}, binding::Union{Nothing, Binding})::Binding
    tokens = getTokens(sourceCode, matchers)
    trees = buildAbstractSyntaxTrees(tokens)
    if binding === nothing
        binding = Binding(nothing, Dict())
    end
    for tree in filter(x -> isa(x, FunctionDefinition), trees)
        binding.identifiers[tree.children[1].text] = tree
    end
    trees = filter(x -> !isa(x, FunctionDefinition), trees)
    for tree in trees
        println(tree.eval(tree, binding))
    end
    binding
end

function runProgram(sourceCode::AbstractString, matchers::Vector{Matcher})::Binding
    return runProgram(sourceCode, matchers, nothing)
end

function repl()
    Base.exit_on_sigint(false)
    binding = nothing
    while true
        try 
            print("> ")
            binding = runProgram(readline(), matchers, binding)
        catch error
            println(error)
            if isa(error, InterruptException)
                exit()
            end
        end
    end
end

if ARGS[1] === "-r"
    repl()
elseif ARGS[1] === "-t"
    runProgram("(defun fib (n blah) (+ 1 3))(+ (- 5 4) 3)(- (- 5 (+ 8 9)) (* 7 5))", matchers)
    runProgram("(defun fib () (+ 1 3))(fib ())", matchers)
    runProgram("(defun fib (n) (+ n 3))(fib 10)", matchers)
    runProgram("(eq 1 1)(eq 2 3)(if (eq 1 1) 1 3)(if (eq 1 2) 1 3)", matchers)
    runProgram("(defun fac (n) (if (eq n 0) 1 (* n (fac (- n 1)))))(fac 10)", matchers)
    runProgram("(defun fac (n) (if (eq n 0) 1 (+ n (fac (- n 1)))))(fac 100)", matchers)
    runProgram("(quote (1 2 3 4 5))", matchers)
    runProgram("(quote (1 2 3 \"hello world \n testing again\" 5))", matchers)
    runProgram("(nil)(cons 1 nil)(cons 2 (cons 1 nil))", matchers)
    runProgram("(eq nil (quote ()))(eq nil nil)(eq nil (quote (1 2 3 4)))", matchers)
    runProgram("(eq nil (quote ()))(eq nil nil)(eq nil (quote (1 2 3 4)))", matchers)
    runProgram("(first (quote (1 2 3 4 5)))(rest (quote (1 2 3 4 5)))(first (quote (7 2 3 4 5)))", matchers)
    runProgram("(defun range (start end) (if (eq start end) (cons start nil) (cons start (range (+ start 1) end))))(range 1 500)", matchers)
    runProgram("(defun test (f) (f 10 20))(defun add (a b) (+ a b))(test add)(test +)(test *)", matchers)
    runProgram("(defun test (a) (+ a 10))(test (+ 10 10))", matchers)
    runProgram("(* \"hello\" (* \" \" \"world\"))", matchers)
    runProgram("(index (* \"hello\" (* \" \" \"world\")) 1)(index (quote (1 2 3 4 5)) 3)", matchers)
    runProgram("(true)(false)(&& true false)(&& true true)(|| true false)(|| false false)(! false)", matchers)
    runProgram("(defun map (f iter) (if (eq iter nil) nil (cons (f (first iter)) (map f (rest iter)))))(defun double (n) (* n 2))(map double (quote (1 2 3 4)))", matchers)
end
