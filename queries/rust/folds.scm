; Replaces nvim-treesitter's rust/folds.scm (same node list) so that a
; function's body only folds on its own when the parameters sit on one
; line. The parameters fold on their own (zc on `fn f(` folds just them);
; when they wrap, their closing `) -> R {` line would also start the body
; fold, and a fold expression gives a line to the fold that starts there,
; cutting the parameters fold a line short. Dropping the body fold in that
; case lets the parameters fold read `fn send( ... ) -> R {` and the
; function fold (a second zc, or zc anywhere in the body) read
; `fn send( ... ) -> R { ... }`.
[
  (mod_item)
  (foreign_mod_item)
  (function_item)
  (struct_item)
  (trait_item)
  (enum_item)
  (impl_item)
  (type_item)
  (union_item)
  (const_item)
  (let_declaration)
  (loop_expression)
  (for_expression)
  (while_expression)
  (if_expression)
  (match_expression)
  (call_expression)
  (array_expression)
  (macro_definition)
  (macro_invocation)
  (attribute_item)
  (use_declaration)+
  (parameters)
] @fold

((block) @fold
  (#not-has-parent? @fold function_item))

((function_item
  parameters: (parameters) @_params
  body: (block) @fold)
  (#not-lua-match? @_params "\n"))
