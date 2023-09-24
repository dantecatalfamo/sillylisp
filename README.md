# sillylisp

A sort-of-a-lisp extracted from a previous project.

Originally intended to be used as a configuration language.
Designed to be easy to grok and fast.
It doesn't have a garbage collector but instead frees everything when the environment is destroyed.
Uses lists instead of cons cells internally.

## Building
```zig
zig build
```

## Running
```zig
zig build run
```
