; treesitter-context: declaration-level scopes only (functions, methods,
; arrows, classes). Overrides the plugin's query, which also pins
; if/for/while/switch, calls, objects, jsx and lexical declarations.

[
  (class_declaration)
  (method_definition)
] @context

(arrow_function
  body: (_
    (_) @context.end)) @context

(function_declaration
  body: (_
    (_) @context.end)) @context

(generator_function_declaration
  body: (_
    (_) @context.end)) @context
