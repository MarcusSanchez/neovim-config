; treesitter-context: declaration-level scopes only (functions, methods,
; arrows, classes, interfaces, enums). Overrides the plugin's query, which
; also pins if/for/while/switch, calls, objects and lexical declarations.

[
  (class_declaration)
  (interface_declaration)
  (enum_declaration)
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
