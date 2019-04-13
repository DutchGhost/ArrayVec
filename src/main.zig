const std = @import("std");
const builtin = @import("builtin");
const debug = std.debug;

const ArrayError = error {
    CapacityError,
};

fn av_from_slice(comptime T: type, comptime slice: []T) ArrayVec(T, slice.len) {
    comptime var array = ArrayVec(T, slice.len).init();
    _ = array.try_extend_from_slice(slice);
    return array;
}

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

        fn iter(self: *const Self) build_iter([*]const T, *const T) {
            const start = self.array[0..].ptr;
            const end = self.array[self.len()..].ptr;
            return build_iter([*]const T, *const T).init(start, end);
        }

        fn iter_mut(self: *Self) build_iter([*]T, *T) {
            const start = self.array[0..].ptr;
            const end = self.array[self.len()..].ptr;
            return build_iter([*]T, *T).init(start, end);
        }

        fn into_iter(self: Self) into_iterator(T, N) {
            return into_iterator(T, N).init(self);
        }

        fn deinit_with(self: *Self, drop_fn: fn(T) void) void {
            for (self.array[0..self._len]) |element| {
                drop_fn(element);
            }
        }
    };
}

fn into_iterator(comptime T: type, comptime N: usize) type {
    return struct {
        array: ArrayVec(T, N),
        index: usize,

        const Self = @This();

        fn init(a: ArrayVec(T, N)) Self {
            return Self {.array = a, .index = 0};
        }

        fn next(self: *Self) ?T {
            if (self.index == self.array._len) {
                return null;
            } else {
                var idx = self.index;
                self.index += 1;
                return self.array.array[idx];
            }
        }
    };
}

/// Returns the mutability of pointer type `T`, but for `R`.
/// *const T will return *const R,
/// *T returns *R.
fn mutability_of(comptime T: type, comptime R: type) type {
    switch (@typeInfo(T)) {
        builtin.TypeId.Pointer => |p| {
            if (p.is_const) {
                return *const R;
            } else {
                return *R;
            }
        },
        else => @compileError("nope"),
    }
}


/// Returns the mutability of pointer type `T`, but for a slice of `T`.
/// *const T will return []const T,
/// *T will return []T.
fn mutability_of_slice(comptime T: type) type {
    switch (@typeInfo(T)) {
        builtin.TypeId.Pointer => |p| {
            if (p.is_const) {
                return []const p.child;
            } else {
                return []p.child;
            }
        },
        else => @compileError("nope"),
    }
}

fn build_iter(comptime T: type, comptime Item: type) type {
     
    return struct {
        ptr: T,
        end: T,

        const Self = @This();

        fn init(start_ptr: T, end_ptr: T) Self {
            return Self { .ptr = start_ptr, .end = end_ptr};
        }

        fn as_slice(self: mutability_of(T, Self)) mutability_of_slice(T) {
            var end_num: usize = @ptrToInt(self.end);
            var ptr_num: usize = @ptrToInt(self.ptr);

            comptime var size_of_t = switch (@typeInfo(Item)) {
                builtin.TypeId.Pointer => |p| blk: {
                    break :blk @sizeOf(p.child);
                },
                else => unreachable,
            };

            // BE CAREFULL. DEVIDE BY THE SIZE OF THE POINTED TO TYPE
            const len = (end_num -% ptr_num) / size_of_t;
            return self.ptr[0..len];
        }

        fn post_inc_start(self: *Self, offset: isize) Item {

            var old = self.ptr;
            self.ptr = self.ptr + @intCast(usize, offset);
            return &old[0];
        }

        fn next(self: *Self) ?Item {
             if (self.ptr == self.end) {
                return null;
            } else {
                return self.post_inc_start(1);
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
    //comptime {
        var vec = ArrayVec(i32, 5).init();
        var array = [5]i32 {1, 2, 3, 4, 5};
        _ = vec.try_extend_from_slice(&array) catch unreachable;
        std.debug.assert(vec.len() == 5);
        var iter = vec.iter();

        debug.assert(iter.next().?.* == 1);
        debug.assert(iter.next().?.* == 2);
        debug.assert(iter.next().?.* == 3);
        debug.assert(iter.next().?.* == 4);
        debug.assert(iter.next().?.* == 5);
        debug.assert(iter.next() == null);
    //}
}

test "iter mut" {
    //comptime {
        var vec = ArrayVec(i32, 5).init();
        var array = [5]i32 {1, 2, 3, 4, 5};
        _ = vec.try_extend_from_slice(&array) catch unreachable;
        std.debug.assert(vec.len() == 5);
        var iter = vec.iter_mut();

        while (iter.next()) |item| {
            item.* += 1;
        }

        debug.assert(std.mem.eql(i32, vec.as_slice(), [5]i32 {2, 3, 4, 5, 6}));
    //}
}

test "iter as slice" {
    //comptime {
        var vec = ArrayVec(i32, 5).init();
        var array = [5]i32 {1, 2, 3, 4, 5};
        _ = vec.try_extend_from_slice(&array) catch unreachable;
        std.debug.assert(vec.len() == 5);
        var iter = vec.iter();

       var slice = iter.as_slice();
       std.debug.assert(slice.len == 5);

       var mutiter = vec.iter_mut();
       var mutslice = mutiter.as_slice();
       mutslice[0] = 0;

       debug.assert(std.mem.eql(i32, vec.as_slice(), [5]i32 {0, 2, 3, 4, 5} ));
    //}
}

test "ino iter" {
    comptime {
        var vec = ArrayVec(i32, 5).init();
        var array = [5]i32 {1, 2, 3, 4, 5};
        _ = vec.try_extend_from_slice(array);

        var iter = vec.into_iter();

        debug.assert(iter.next().? == 1);
        debug.assert(iter.next().? == 2);
        debug.assert(iter.next().? == 3);
        debug.assert(iter.next().? == 4);
        debug.assert(iter.next().? == 5);
        debug.assert(iter.next() == null);

        var it = vec.into_iter();
    }
}

test "av_from_slice" {
    comptime {
        var arr = [5]i32 {1, 2, 3, 4, 5};
        var v = av_from_slice(i32, &arr);
        debug.assert(v.len() == 5);
        debug.assert(v.capacity() == 5);
    }
}