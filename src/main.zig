const std = @import("std");
const debug = std.debug;

const ArrayError = error {
    CapacityError,
};

pub fn ArrayVec(comptime T: type, comptime N: usize) type {
    return struct {
        array: [N]T,
        _len: usize,

        const Capacity = N;
        const Self = @This();
        
        fn init() Self {
            return Self { .array = undefined, ._len = comptime_int(0)};
        }

        fn len(self: *const Self) usize {
            return self._len;
        }

        fn remaining_capacity(self: *const Self) usize {
            return Capacity - self.len();
        }
        fn push(self: *Self, element: T) void {
            return self.try_push(element) catch unreachable;
        }

        fn try_push(self: *Self, element: T) !void {
            if (self.len() < Capacity) {
                return self.push_unchecked(element);
            } else {
                return ArrayError.CapacityError;
            }
        }

        fn push_unchecked(self: *Self, element: T) void {
            var self_len = self.len();
            debug.assert(self_len < Capacity);
            self.array[self_len] = element;
            self.set_len(self_len + 1);
        }

        fn set_len(self: *Self, length: usize) void {
            debug.assert(length <= Capacity);
            self._len = length;
        }

        fn pop(self: *Self) ?T {
            if (self.len() == 0) {
                return null;
            }
            var new_len = self._len - 1;
            self.set_len(new_len);
            return self.array[new_len];
        }

        fn try_extend_from_slice(self: *Self, other: []const T) !void {
            if (self.remaining_capacity() < other.len) {
                return ArrayError.CapacityError;
            }

            var self_len = self.len();
            var other_len = other.len;

            std.mem.copy(T, self.array[self_len..], other);
            self.set_len(self_len + other_len);
        }
    };
}

test "arrayvec push" {
    comptime var vec = comptime ArrayVec(i32, 4).init();
    
    comptime vec.push(1);
    comptime vec.push(2);
    comptime vec.push(3);
    comptime vec.push(4);

    comptime debug.assert(vec.len() == 4);
}

test "arrayvec pop" {
    comptime var vec = comptime ArrayVec(i32, 4).init();
    
    comptime vec.push(1);
    comptime vec.push(2);
    comptime vec.push(3);
    comptime vec.push(4);
    comptime debug.assert(vec.len() == 4);

    comptime debug.assert(vec.pop().? == 4);    
    comptime debug.assert(vec.pop().? == 3);
    comptime debug.assert(vec.pop().? == 2);
    comptime debug.assert(vec.pop().? == 1);
    comptime debug.assert(vec.pop() == null);

    comptime debug.assert(vec.len() == 0);    
}

test "extend from slice" {
    comptime var vec = comptime ArrayVec(i32, 10).init();

    comptime vec.push(1);

    comptime var array = [9]i32 {2, 3, 4, 5, 6, 7, 8, 9, 10};
    
    comptime vec.try_extend_from_slice(&array) catch unreachable;

    comptime debug.assert(vec.len() == 10);

    comptime debug.assert(vec.pop().? == 10);
    
}