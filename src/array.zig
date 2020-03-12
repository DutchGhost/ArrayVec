pub const ArrayError = error{CapacityError};

pub fn ArrayVec(comptime T: type, comptime SIZE: usize) type {
    return struct {
        array: [SIZE]T,
        length: usize,

        const Self = @This();

        fn set_len(self: *Self, new_len: usize) void {
            self.length = new_len;
        }

        /// Returns a new, empty ArrayVec.
        pub fn new() Self {
            return Self{
                .array = undefined,
                .length = @as(usize, 0),
            };
        }

        /// Returns the length of the ArrayVec
        pub fn len(self: *const Self) usize {
            return self.length;
        }

        /// Returns the capacity of the ArrayVec
        pub fn capacity(self: *const Self) usize {
            return SIZE;
        }

        /// Returns a boolean indicating whether
        /// the ArrayVec is full
        pub fn isFull(self: *const Self) bool {
            return self.len() == self.capacity();
        }

        /// Returns a boolean indicating whether
        /// the ArrayVec is empty
        pub fn isEmpty(self: *const Self) bool {
            return self.len() == 0;
        }

        /// Returns the remaing capacity of the ArrayVec.
        /// This is the number of elements remaing untill
        /// the ArrayVec is full.
        pub fn remainingCapacity(self: *const Self) usize {
            return self.capacity() - self.len();
        }

        /// Returns a const slice to the underlying memory
        pub fn asConstSlice(self: *const Self) []const T {
            return self.array[0..self.len()];
        }

        /// Returns a (mutable) slice to the underlying
        /// memory.
        pub fn asSlice(self: *Self) []T {
            return self.array[0..self.len()];
        }

        /// Truncates the ArrayVec to the new length. It is
        /// the programmers responsability to deallocate any
        /// truncated elements if nessecary.
        /// Notice that truncate is lazy, and doesn't touch
        /// any truncated elements.
        pub fn truncate(self: *Self, new_len: usize) void {
            if (new_len < self.len()) {
                self.set_len(new_len);
            }
        }

        /// Clears the entire ArrayVec. It is
        /// the programmers responsability to deallocate the
        /// cleared items if nessecary.
        /// Notice that clear is lazy, and doesn't touch any
        /// cleared items.
        pub fn clear(self: *Self) void {
            self.truncate(0);
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

        pub fn extend_from_slice(self: *Self, other: []const T) !void {
            if (self.remainingCapacity() >= other.len) {
                self.extend_from_slice_unchecked(other);
            } else {
                return ArrayError.CapacityError;
            }
        }

        pub fn extend_from_slice_unchecked(self: *Self, other: []const T) void {
            @setRuntimeSafety(false);
            const mem = @import("std").mem;

            mem.copy(T, self.array[self.length..], other);
            self.set_len(self.length + other.len);
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

test "extend from slice" {
    const CAP: usize = 10;
    const SLICE = &[_]i32{ 1, 2, 3, 4, 5, 6 };
    comptime {
        var array = ArrayVec(i32, CAP).new();
        try array.extend_from_slice(SLICE);

        testing.expectEqual(array.len(), SLICE.len);

        for (array.asConstSlice()) |elem, idx| {
            testing.expectEqual(elem, SLICE[idx]);
        }
    }
}
