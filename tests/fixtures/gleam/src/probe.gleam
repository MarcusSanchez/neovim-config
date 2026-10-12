import probe/int
import probe/io
import probe/list
import probe/option.{type Option, None, Some}

pub type Shape {
  Circle(radius: Float)
  Rect(width: Float, height: Float)
}

pub type Tree(a) {
  Leaf
  Node(
    left: Tree(a),
    value: a,
    right: Tree(a),
  )
}

pub fn area(shape: Shape) -> Float {
  case shape {
    Circle(radius) -> 3.14 *. radius *. radius
    Rect(width, height) -> {
      let w = width
      w *. height
    }
  }
}

pub fn insert(
  tree: Tree(Int),
  value: Int,
) -> Tree(Int) {
  case tree {
    Leaf -> Node(Leaf, value, Leaf)
    Node(left, v, right) -> {
      case value < v {
        True -> Node(insert(left, value), v, right)
        False -> {
          Node(left, v, insert(right, value))
        }
      }
    }
  }
}

pub fn describe(values: List(Int)) -> Option(String) {
  let total =
    values
    |> list.map(fn(x) {
      x * 2
    })
    |> list.fold(0, fn(acc, x) { acc + x })
  let names = [
    "one",
    "two",
  ]
  use <- bool_guard(total > 0)
  let message = int.to_string(
    total,
  )
  io.println(message)
  case names {
    [] -> None
    [first, ..] -> Some(first)
  }
}

fn bool_guard(cond: Bool, next: fn() -> Option(String)) -> Option(String) {
  case cond {
    True -> next()
    False -> None
  }
}

/// Documentation line one
/// Documentation line two
pub fn main() {
  io.println("hi")
  let _ = area(Circle(1.0))
  let _ = insert(Leaf, 1)
  let _ = describe([1, 2])
}

pub type Config {
  Config(name: String, retries: Int, verbose: Bool)
}

pub fn extras(config: Config) -> #(String, Int) {
  let updated =
    Config(
      ..config,
      retries: 3,
    )
  let pair = #(
    updated.name,
    updated.retries,
  )
  let bits = <<
    1,
    2,
  >>
  let _ = bits
  let add = fn(
    a: Int,
    b: Int,
  ) {
    a + b
  }
  let _ = add(1, 2)
  pair
}
