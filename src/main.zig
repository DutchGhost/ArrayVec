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

        fn capacity(self: *const Self) usize {
            return Capacity;
        }

        fn as_slice(self: *const Self) []const T {
            return self.array[0..self.len()];
        }

        fn as_slice_mut(self: *Self) []T {
            return self.array[0..self.len()];
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

        fn iter(self: *const Self) type {
            // return struct {
            //     ptr: *const T,
            //     end: *const T,

            //     const Iter = @This();
                
            //     fn post_inc_start(this: *Iter, offset: isize) *const T {
            //         // oh well, zero sized types :3
            //         if (comptime @sizeOf(T) == 0) {
            //             this.end = @intToPtr(*const T, (@ptrToInt(this.end)) +% -offset);
            //             return this.ptr;
            //         } else {
            //             var old = this.ptr;
            //             this.ptr = @intToPtr(*const T, @ptrToInt(this.end) + 1);
            //             return old;
            //         }
            //     }

            //     fn next(this: *Iter) ?*const T {
            //         if (this.ptr == this.end) {
            //             return null;
            //         } else {
            //             return this.post_inc_start(1);
            //         }
            //     }
            // };

            var start: *const T = &self.array[0];
            var offset = @ptrToInt(start) + self.len();

            const end = @intToPtr(*const T, offset);
            return build_iter(*const T).init(start, end);
        }
    };
}

fn build_iter(comptime T: type) type {
    return struct {
        ptr: T,
        end: T,

        const Self = @This();
        
        fn init(start_ptr: T, end_ptr: T) Self {
            return Self { .ptr = start_ptr, .end = end_ptr};
        }

        fn post_inc_start(this: *Self, offset: isize) T {
            // oh well, zero sized types :3
            if (comptime @sizeOf(T) == 0) {
                this.end = @intToPtr(T, (@ptrToInt(this.end)) +% -offset);
                return this.ptr;
            } else {
                var old = this.ptr;
                this.ptr = @intToPtr(T, @ptrToInt(this.end) + 1);
                return old;
            }
        }

        fn next(this: *Self) T {
            if (this.ptr == this.end) {
                return null;
            } else {
                return this.post_inc_start(1);
            }
        }
    };
}

test "arrayvec push" {
    comptime {
        var vec = ArrayVec(i32, 4).init();

        vec.push(1);
        vec.push(2);
        vec.push(3);
        vec.push(4);

        debug.assert(vec.len() == 4);
        debug.assert(std.mem.eql(i32, vec.as_slice(), [4]i32 {1, 2, 3, 4}));
    }
}

test "arrayvec pop" {
    comptime {
        var vec = ArrayVec(i32, 4).init();
    
        vec.push(1);
        vec.push(2);
        vec.push(3);
        vec.push(4);
        debug.assert(vec.len() == 4);

        debug.assert(vec.pop().? == 4);    
        debug.assert(vec.pop().? == 3);
        debug.assert(vec.pop().? == 2);
        debug.assert(vec.pop().? == 1);
        debug.assert(vec.pop() == null);

        debug.assert(vec.len() == 0);
        debug.assert(std.mem.eql(i32, vec.as_slice(), [0]i32 {}));
    }
}

test "extend from slice" {
    
    comptime {
        var vec = ArrayVec(i32, 10).init();

        vec.push(1);

        var array = [9]i32 {2, 3, 4, 5, 6, 7, 8, 9, 10};
    
        vec.try_extend_from_slice(&array) catch unreachable;

        debug.assert(vec.len() == 10);

        debug.assert(vec.pop().? == 10);
    }
}

test "iter" {
    comptime {
        var vec = ArrayVec(i32, 10).init();
        var array = [10]i32 {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
        vec.try_extend_from_slice(&array) catch unreachable;
        var iter = vec.iter();
        var nxt = iter.next();
    }
}