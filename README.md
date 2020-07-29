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
To run the generated file you should look at the generated folder named `output` and your files will be avalible there.  Then you can run them like this.
```
[source-file-name].lua
```
so, for examle `example.ptls` would turn into `example.lua`.
