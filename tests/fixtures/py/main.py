import os
import sys
from typing import (
    Any,
    Optional,
)


# a comment
# spanning lines
class Tree:
    """Doc string
    spanning lines.
    """

    def __init__(self, value: int) -> None:
        self.value = value
        self.children: list["Tree"] = []

    def insert(
        self,
        value: int,
        depth: int = 0,
    ) -> "Tree":
        if value < self.value:
            node = Tree(value)
            self.children.append(node)
        elif value == self.value:
            pass
        else:
            node = Tree(
                value,
            )
            self.children.insert(0, node)
        for child in self.children:
            print(child.value)
        while depth > 0:
            depth -= 1
        try:
            os.stat("x")
        except OSError as e:
            print(e, file=sys.stderr)
        finally:
            pass
        with open("x") as f:
            f.read()
        data = {
            "a": 1,
            "b": [
                1,
                2,
            ],
        }
        return node


def main() -> Optional[Any]:
    tree = Tree(1)
    tree.insert(2)
    return None
