; treesitter-context: declaration-level scopes only. Overrides the plugin's
; query (no `;; extends`), which also pins loops, ifs, matches, blocks and
; call sites — inside a big `loop {}` the header would just say "loop".

(function_item
  body: (_
    (_) @context.end)) @context

(closure_expression
  body: (_
    (_) @context.end)) @context

(impl_item
  body: (_
    (_) @context.end)) @context

(trait_item
  body: (_
    (_) @context.end)) @context

(struct_item
  body: (_
    (_) @context.end)) @context

(union_item
  body: (_
    (_) @context.end)) @context

(enum_item
  body: (_
    (_) @context.end)) @context

(mod_item
  body: (_
    (_) @context.end)) @context

(foreign_mod_item
  body: (_
    (_) @context.end)) @context
