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
* Operators and function can be used in the same contexts and will behave identically
* String concatentation is performed by using the `*` operator
* There is an operator called `index` for accesing specific indexes of string or lists
* It features `juliaReduce` and `juliaRange` operators which are wrappers around Julia's `reduce` and `range` functions
* The maximum call stack size depends on the memory that is available to the computer it is being run on
* It supports the following data types `Int`, `Bool`, `List` and `String`

## Contributing

All of the source code is located in `v2.jl`. `v1.jl` includes code for a previous prototype version. The learnings from this version were used to create the second current verion.
