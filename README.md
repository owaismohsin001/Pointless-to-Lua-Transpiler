# Pointless to Lua transpiler
This transpiler is an implementation of a declarative and functional programming lanuage named [Pointless](https://github.com/pointless-lang/pointless/). It compiles that to Lua. Currently it does object tracking for error reporting and greets you with error messages with line numbers. It also detects errors like duplicate definitions and undefined variables at compile-time.

# How to use
It's very simple, first you build it with your favorite flags with nim's compiler then you write command like this,
```
compiler example.ptls
```
So basically, file name orf the compiler followed by that of the source file you need to compile.
```
[compiler-exe-name] [source-file-name]
```
