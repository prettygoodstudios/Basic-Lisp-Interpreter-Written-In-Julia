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
                        # Evaluate function calls
                        if isa(value, Identifier) && length(value.children) !== 0
                            newBinding.identifiers[name] = Literal("Cached result 1:", value.eval(value, binding))
                            continue
                        end
                        if isa(value, Identifier)
                            value = lookupInBinding(binding, value.text)
                        end
                        # If it can be evaluated, evaluate it
                        # Functions and operators cannot be directly evaluated
                        if !isa(value, FunctionDefinition) && (!isa(value, Operator) || length(value.children) !== 0)
                            value = Literal("Cached result:", value.eval(value, binding))
                        end
                        newBinding.identifiers[name] = value
                    end
                end
                return token.eval(token, newBinding)
            end
            token = deepcopy(token)
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

function runProgram(sourceCode::AbstractString, matchers::Vector{Matcher}, binding::Union{Nothing, Binding})::Tuple{Binding,Vector}
    tokens = getTokens(sourceCode, matchers)
    trees = buildAbstractSyntaxTrees(tokens)
    if binding === nothing
        binding = Binding(nothing, Dict())
    end
    for tree in filter(x -> isa(x, FunctionDefinition), trees)
        binding.identifiers[tree.children[1].text] = tree
    end
    trees = filter(x -> !isa(x, FunctionDefinition), trees)
    output = []
    for tree in trees
        push!(output, tree.eval(tree, binding))
    end
    binding, output
end

function runProgram(sourceCode::AbstractString, matchers::Vector{Matcher})::Tuple{Binding,Vector}
    return runProgram(sourceCode, matchers, nothing)
end

function repl()
    Base.exit_on_sigint(false)
    binding = nothing
    while true
        try 
            print("> ")
            binding,output = runProgram(readline(), matchers, binding)
            println(output)
        catch error
            println(error)
            if isa(error, InterruptException)
                exit()
            end
        end
    end
end

function runFromFile(fileName::String)::Binding
    program = ""
    for line in eachline(fileName)
        program *= "$line\n"
    end
    binding, output = runProgram(program, matchers)
    for line in output
        println(line)
    end
    binding
end

if ARGS[1] === "-r"
    repl()
elseif ARGS[1] === "-t"
    _, output = runProgram("(eq 1 1)(eq 2 3)(if (eq 1 1) 1 3)(if (eq 1 2) 1 3)", matchers)
    println(output)
    @assert Tuple([true, false, 1, 3]) == Tuple(output)
    _, output = runProgram("(defun fac (n) (if (eq n 0) 1 (* n (fac (- n 1)))))(fac 10)", matchers)
    println(output)
    @assert 3628800 == output[1]
    _, output = runProgram("(quote (1 2 3 4 5))", matchers)
    println(output)
    _, output = runProgram("(quote (1 2 3 \"hello world \n testing again\" 5))", matchers)
    println(output)
    @assert Tuple([1,2,3,"hello world \n testing again",5]) == Tuple(output[1])
    _, output = runProgram("(nil)(cons 1 nil)(cons 2 (cons 1 nil))", matchers)
    println(output)
    @assert Tuple([Tuple([]), Tuple([1]), Tuple([2,1])]) == Tuple(map(x -> Tuple(x), output))
    _, output = runProgram("(eq nil (quote ()))(eq nil nil)(eq nil (quote (1 2 3 4)))", matchers)
    println(output)
    @assert Tuple([true, true, false]) == Tuple(output)
    _, output = runProgram("(first (quote (1 2 3 4 5)))(rest (quote (1 2 3 4 5)))(first (quote (7 2 3 4 5)))", matchers)
    println(output)
    @assert Tuple([1, Tuple([2,3,4,5]), 7]) == Tuple([output[1], Tuple(output[2]), output[3]])
    _, output = runProgram("(defun range (start end) (if (eq start end) (cons start nil) (cons start (range (+ start 1) end))))(range 1 500)", matchers)
    println(output)
    @assert Tuple(output[1]) == Tuple([x for x in range(1,500)])
    _, output = runProgram("(defun test (f) (f 10 20))(defun add (a b) (+ a b))(test add)(test +)(test *)", matchers)
    println(output)
    @assert Tuple([30, 30, 200]) == Tuple(output)
    _, output = runProgram("(defun test (a) (+ a 10))(test (+ 10 10))", matchers)
    println(output)
    @assert 30 == output[1]
    _, output = runProgram("(* \"hello\" (* \" \" \"world\"))", matchers)
    println(output)
    @assert "hello world" === output[1]
    _, output = runProgram("(index (* \"hello\" (* \" \" \"world\")) 1)(index (quote (1 2 3 4 5)) 3)", matchers)
    println(output)
    @assert output[1]*"" === "h"
    @assert output[2] == 3
    _, output = runProgram("(true)(false)(&& true false)(&& true true)(|| true false)(|| false false)(! false)", matchers)
    println(output)
    @assert Tuple(output) === Tuple([true, false, false, true, true, false, true])
    _, output = runProgram("(defun map (f iter) (if (eq iter nil) nil (cons (f (first iter)) (map f (rest iter)))))(defun double (n) (* n 2))(map double (quote (1 2 3 4)))", matchers)
    println(output)
    @assert Tuple([2,4,6,8]) == Tuple(output[1])
    _, output = runProgram("""
    (defun reduce (f a i) 
    (if (eq a nil)
        i
        (reduce f (rest a) (f i (first a)))
    )
    )
    (defun sum (a b) (+ a b))
    (defun test (f a b) (f a b))
    (reduce + (quote (1 7 3 4 5)) 0)
    (test + (test + 10 10) 10)
    """, matchers)
    @assert Tuple([20, 30]) == Tuple(output)
elseif ARGS[1] === "-f"
    runFromFile(ARGS[2])
end
