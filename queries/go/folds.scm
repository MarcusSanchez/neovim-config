; Replaces nvim-treesitter's go/folds.scm (same node list) so that a
; function's body only folds on its own when the parameters sit on one
; line. The parameters fold on their own (zc on `func f(` folds just them);
; when they wrap, their closing `) T {` line would also start the body
; fold, and a fold expression gives a line to the fold that starts there,
; cutting the parameters fold a line short. Dropping the body fold in that
; case lets the parameters fold read `func h( ... ) int {` and the function
; fold (a second zc, or zc anywhere in the body) read `func h( ... ) int { ... }`.
[
  (const_declaration)
  (expression_switch_statement)
  (expression_case)
  (default_case)
  (type_switch_statement)
  (type_case)
  (for_statement)
  (func_literal)
  (function_declaration)
  (if_statement)
  (import_declaration)
  (method_declaration)
  (type_declaration)
  (var_declaration)
  (composite_literal)
  (literal_element)
  (parameter_list)
] @fold

((block) @fold
  (#not-has-parent? @fold function_declaration method_declaration func_literal))

((function_declaration
  parameters: (parameter_list) @_params
  body: (block) @fold)
  (#not-lua-match? @_params "\n"))

((method_declaration
  parameters: (parameter_list) @_params
  body: (block) @fold)
  (#not-lua-match? @_params "\n"))

((func_literal
  parameters: (parameter_list) @_params
  body: (block) @fold)
  (#not-lua-match? @_params "\n"))
