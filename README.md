# Basic Lisp Interpreter Written in Julia

> Miguel Rust

## Description

This project implements a basic lisp interpreter in Julia. Features that are supported by this interpreter include a REPL (Read Eval Print Loop), executing source code from specified files and a basic test suite.

## Usage

The interpreter can enter REPL mode by running the following command from the root of this project `julia v2.jl -r`. Commands are executed in the REPL by typing them in the prompt and hitting enter. The REPL binds all functions to the same lexical enviroment. This allows for calling function defined in previous executions in the same REPL session. A file can be by the interpreter by running the following command from the root directory of the project `julia v2.jl -f FILE_NAME`. The name of the file will replace `FILE_NAME`. The test suite can be run by running `julia v2.jl -t` from the root directory of the project.

## Features of this interpreter's dialect of Lisp

* Functions are first class values
* Operators are first class values
* Functions are "hoisted", therefore, where a function appears in a file is irrelevant
* Operators and functions can be used in the same contexts and will behave identically (Their implementations are different so there are performance implications)
* String concatentation is performed by using the `*` operator
* There is an operator called `index` for accesing specific indexes of string or lists
* It features `juliaReduce` and `juliaRange` operators which are wrappers around Julia's `reduce` and `range` functions
* The maximum call stack size depends on the memory that is available to the computer it is being run on
* It supports the following data types `Int`, `Bool`, `List` and `String`

### Literals

* `String`: Strings are denoted using double quotes i.e. `"hello world"`. Strings support multiple lines.
* `Int`: Ints are denoted by numbers without decimal points or commas i.e. `55`.
* `List`: List literals are denoted by the quote operator provided with a list i.e. `(quote (1 2 3 4 5))`. In addition, empty lists are denoted by `nil`.
* `Bool`: There are two literals for bools `true` and `false`.

### Operators

#### Boolean

* `eq`: Usage: `(eq a b)` a and b can be any value. It returns `true` if the two arguments supplied are equal, in all other circumstances it returns `false`.
* `&&`: Usage: `(&& a b)` a and b can be anything that evaluates to a `Bool`. Returns `true` if both arguments evaluate to `true` otherwise it returns `false`.
* `||`: Usage: `(|| a b)` a and b can be anything that evaluates to a `Bool`. It returns true if one of the arguments evaluates to `true` otherwise it returns `false`.
* `lt`: Usage `(lt a b)` a and b can be any value. It returns `true` if `a` is less than `b` otherwise it returns `false`.
* `gt`: Usage `(lt a b)` a and b can be any value. It returns `true` if `a` is greater than `b` otherwise it returns `false`.

#### Arithmetic

* `+`: Usage `(+ a b)` a and b can be anthing that evaulates to an `Int`. It returns the sum of the two arguments.
* `-`: Usage `(- a b)` a and b can be anthing that evaulates to an `Int`. It returns the difference of the two arguments.
* `*`: Usage `(* a b)` a and b can be anthing that evaulates to an `Int` or `String`. It returns the product of the two arguments, if the two arguments are ints. If the two arguments are strings, then it will return the two string concatenated.
* `/`: Usage `(/ a b)` a and b can be anthing that evaulates to an `Int`. It returns the quotient of the two arguments, when performing integer division.

#### Control flow and miscelanous

* `if`: Usage `(if a b c)` or `(if a b)` a is anything that evaluates to a `Bool` b and c can be any values. If `a` is `true` it will evaluate and return `b`, else it will evaluate and return `c` if it is provided. If `c` is not provided and it `a` evaluates to `false` no value will be returned.
* `juliaReduce`: Usage `(juliaReduce f a i)` f is a function or operator name/identifier, a is a list and i is the initial value for the accumulator. For example, the following code `(juliaReduce * (quote (1 2 3) 1)` would evaluate to `6`. This operator is a wrapper around [Julia's reduce function](https://docs.julialang.org/en/v1/base/collections/#Base.reduce-Tuple{Any,%20Any}). This operator can be used to perform looping and iterative computation without relying on recursion.
* `juliaRange`: Usage `(juliaRange s e)` s is an `Int` that is the start of the range and e is an `Int` that is the end of the range i.e. `(juliaRange 1 10)` produces the following list `(quote (1 2 3 4 5 6 7 8 9 10))`. It is a wrapper around Julia's range function.

## Contributing

All of the source code is located in `v2.jl`. `v1.jl` includes code for a previous prototype version. The learnings from this version were used to create the second current verion.
