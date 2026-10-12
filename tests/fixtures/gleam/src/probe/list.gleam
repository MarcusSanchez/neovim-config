pub fn map(items: List(a), f: fn(a) -> b) -> List(b) {
  case items {
    [] -> []
    [first, ..rest] -> [f(first), ..map(rest, f)]
  }
}

pub fn fold(items: List(a), acc: b, f: fn(b, a) -> b) -> b {
  case items {
    [] -> acc
    [first, ..rest] -> fold(rest, f(acc, first), f)
  }
}
