const std = @import("std");
const Allocator = std.mem.Allocator;

const Node = struct {
    left: ?*Node = null,
    right: ?*Node = null,
    value: i32,

    fn init(allocator: Allocator, value: i32, parent: ?*Node) !*Node {
        const n = try allocator.create(Node);
        n.* = .{ .value = value };
        _ = parent;
        return n;
    }
};

pub const Tree = struct {
    allocator: Allocator,
    root: ?*Node = null,

    fn insertNode(self: *Tree, node: *Node, value: i32) !*Node {
        if (value < node.value) {
            if (node.left) |left| {
                return self.insertNode(left, value);
            } else {
                node.left = try Node.init(self.allocator, value, node);
                return node.left.?;
            }
        } else {
            if (node.right) |right| {
                return self.insertNode(right, value);
            } else {
                node.right = try Node.init(self.allocator, value, node);
                return node.right.?;
            }
        }
    }

    pub fn describe(
        self: *Tree,
        depth: u32,
    ) u32 {
        _ = self;
        const total = switch (depth) {
            0 => 1,
            1 => 2,
            else => blk: {
                const d = depth * 2;
                break :blk d;
            },
        };
        const items = [_]u32{
            1,
            2,
        };
        const sum = std.math.add(
            u32,
            items[0],
            items[1],
        ) catch 0;
        while (depth > 0) {
            std.debug.print("{d}\n", .{depth});
        }
        return total + sum;
    }
};

/// Doc comment one
/// Doc comment two
pub fn main() !void {
    var tree = Tree{ .allocator = std.heap.page_allocator };
    _ = tree.describe(1);
    _ = &tree;
}

const Point = struct { x: i32, y: i32 };

fn extras(allocator: Allocator, n: usize) !void {
    const p = Point{
        .x = 1,
        .y = 2,
    };
    const buf = try allocator.alloc(u8, n);
    defer allocator.free(buf);
    for (buf, 0..) |*b, i| {
        b.* = @intCast(i);
    }
    if (n > p.x) {
        std.debug.print("big\n", .{});
    }
    const v = n orelse_block: {
        break :orelse_block 0;
    };
    _ = v;
    std.debug.print(
        "{d} {d}\n",
        .{ p.x, p.y },
    );
}

test "extras" {
    try extras(std.testing.allocator, 3);
}
