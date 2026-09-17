; treesitter-context: declaration-level scopes only (functions, methods,
; closures, type declarations). Overrides the plugin's query, which also pins
; if/for/select/switch bodies and composite literals.

(type_declaration) @context

(function_declaration
  body: (block
    (_) @context.end)) @context

(method_declaration
  body: (block
    (_) @context.end)) @context

(func_literal
  body: (block
    (_) @context.end)) @context
