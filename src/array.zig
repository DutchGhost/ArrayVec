pub const ArrayError = error{CapacityError};

pub fn ArrayVec(comptime T: type, comptime SIZE: usize) type {
    return struct {
        array: [SIZE]T,
        length: usize,

        const Self = @This();

        fn set_len(self: *Self, new_len: usize) void {
            self.length = new_len;
        }

        pub fn new() Self {
            return Self{
                .array = undefined,
                .length = @as(usize, 0),
            };
        }

        pub fn len(self: *const Self) usize {
            return self.length;
        }

        pub fn capacity(self: *const Self) usize {
            return SIZE;
        }

        pub fn isFull(self: *const Self) bool {
            return self.len() == self.capacity();
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.len() == 0;
        }

        pub fn remainingCapacity(self: *const Self) usize {
            return self.capacity() - self.len();
        }

        pub fn asConstSlice(self: *const Self) []const T {
            return self.array[0..self.len()];
        }

        pub fn asSlice(self: *Self) []T {
            return self.array[0..self.len()];
        }

        pub fn push(self: *Self, element: T) !void {
            if (self.len() < self.capacity()) {
                self.push_unchecked(element);
            } else {
                return ArrayError.CapacityError;
            }
        }

        pub fn push_unchecked(self: *Self, element: T) void {
            @setRuntimeSafety(false);

            const self_len = self.len();
            self.array[self_len] = element;
            self.set_len(self_len + 1);
        }

        pub fn pop(self: *Self) ?T {
            if (!self.isEmpty()) {
                return self.pop_unchecked();
            } else {
                return null;
            }
        }

        pub fn pop_unchecked(self: *Self) T {
            @setRuntimeSafety(false);

            const new_len = self.len() - 1;
            self.set_len(new_len);
            return self.array[new_len];
        }
    };
}

const testing = if (@import("builtin").is_test)
    struct {
        fn expectEqual(x: var, y: var) void {
            @import("std").debug.assert(x == y);
        }
    }
else
    void;

test "test new" {
    comptime {
        var array = ArrayVec(i32, 10).new();
    }
}

test "test len, cap, empty" {
    const CAP: usize = 20;

    comptime {
        var array = ArrayVec(i32, CAP).new();

        testing.expectEqual(array.isEmpty(), true);
        testing.expectEqual(array.len(), 0);
        testing.expectEqual(array.capacity(), CAP);
        testing.expectEqual(array.remainingCapacity(), CAP);
    }
}

test "try push" {
    const CAP: usize = 10;

    comptime {
        var array = ArrayVec(i32, CAP).new();

        comptime var i = 0;

        inline while (i < CAP) {
            i += 1;

            try array.push(i);
            testing.expectEqual(array.len(), i);
            testing.expectEqual(array.remainingCapacity(), CAP - i);
        }

        testing.expectEqual(array.isFull(), true);
    }
}

test "try pop" {
    const CAP: usize = 10;

    comptime {
        var array = ArrayVec(i32, CAP).new();
        comptime var i = 0;

        {
            inline while (i < CAP) {
                i += 1;
                try array.push(i);
                defer if (array.pop()) |elem| testing.expectEqual(elem, i) else @panic("Failed to pop");
            }
        }

        testing.expectEqual(array.isEmpty(), true);
    }
}
