const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const debug = std.debug;

/// An errorset for an ArrayVec
const ArrayError = error {
    CapacityError,
};

/// [V] new() -> Self
/// [V] len(self: Self) -> usize
/// [V] capacity(self: Self) -> usize
/// [V] is_full(self: Self) -> bool
/// [V] remaining_capacity(self: Self) -> usize
/// [V] push(self: *Self, element: T) void
/// [V] try_push(self: *Self) !void
/// [V] push_unchecked(self: *Self): void
/// [V] insert(self: *Self, index: usize, element: T) void
/// [X] try_insert(self: *Self, index: usize, element: T) !void
/// [V] pop(self: *Self) ?T
/// [V] swap_remove(self: *Self, index: usize) T
/// [V] swap_pop(self: *Self, index: usize) ?T
/// [V] remove(self: *Self, index: usize) T
/// [V] pop_at(self: *Self, index: usize) ?T
/// [V] truncate(self: *Self, new_len: usize) void
/// [V] clear(self: *Self) void
/// [V] retain(self: *Self, f: fn(*T) -> bool) void
/// [V] set_len(self: *Self, new_len: usize) void
/// [V] try_extend_from_slice(self: *Self, other: []T) !void
/// [V] drain(self: *Self, start: usize, end: usize) Drain(T),
/// [V] into_inner(self: Self) -> [SIZE]T
/// [V] dispose(self: Self) void
/// [V] as_slice(self: Self) []const T
/// [V] as_mut_slice(self: *Self) []T
pub fn ArrayVec(comptime T: type, comptime SIZE: usize) type {
    return struct {
        array: [SIZE]T,
        length: usize,

        const Self = @This();

        /// Returns a new empty ArrayVec.
        pub fn new() Self {
            return Self {
                .array = undefined, .length = comptime_int(0),
            };
        }

        /// Returns the length of the ArrayVec.
        pub fn len(self: Self) usize {
            return self.length;
        }

        /// Returns the capacity of the ArrayVec.
        pub fn capacity(self: Self) usize {
            return SIZE;
        }

        pub fn is_full(self: Self) bool {
            return self.len() == self.capacity();
        }

        pub fn is_empty(self: Self) bool {
            return self.len() == 0;
        }

        pub fn remaining_capacity(self: Self) usize {
            return self.capacity() - self.len();
        }

        /// Pushes `element` onto the array.
        /// Panic's if the array was already full.
        pub fn push(self: *Self, element: T) void {
            self.try_push(element) catch {
                @panic("ArrayVec.push failed: Out of Capacity.");
            };
        }

        /// Pushes `element` onto the array.
        /// If the array was already full,
        /// An error is returned.
        pub fn try_push(self: *Self, element: T) !void {
            if (self.len() < self.capacity()) {
                self.push_unchecked(element);
            } else {
                return ArrayError.CapacityError;
            }
        }

        /// Pushes `element` onto the array.
        /// This function does *NOT* boundscheck.
        pub fn push_unchecked(self: *Self, element: T) void {
            // Store the length in a variable for reuse.
            var self_len = self.len();

            debug.assert(self_len < self.capacity());
            self.array[self_len] = element;
            self.set_len(self_len + 1);
        }

        pub fn insert(self: *Self, index: usize, element: T) void {
            self.try_insert(index, element) catch unreachable;
        }

        pub fn try_insert(self: *Self, index: usize, element: T) !void {
            unreachable;
        }
        
        /// Remove the last element in the array and return it.
        pub fn pop(self: *Self) ?T {
            if (self.is_empty()) {
                return null;
            } else {
                const new_len = self.len() - 1;
                self.set_len(new_len);
                return self.array[new_len];
            }
        }

        fn swap(self: *Self, a: usize, b: usize) void {
            var tmp = self.array[a];
            self.array[a] = self.array[b];
            self.array[b] = tmp;
        }
        pub fn swap_remove(self: *Self, index: usize) T {
            return self.swap_pop(index) catch unreachable;
        }

        pub fn swap_pop(self: *Self, index: usize) ?T {
            var len = self.len();
            if (index > len) { return null; }
            self.swap(index, len - 1);
            return self.pop();
        }

        pub fn remove(self: *Self, index: usize) T {
            return self.pop_at(index) orelse unreachable;
        }

        pub fn pop_at(self: *Self, index: usize) ?T {
            if (index >= self.len()) {
                return null;
            } else {
                var drainit = self.drain(index, index + 1);
                var ret = drainit.next();
                defer drainit.deinit();
                return ret;
            }
        }

        pub fn truncate(self: *Self, new_len: usize) void {
            if (new_len < self.len()) {
                self.len = new_len;
            }
        }

        pub fn truncate_with_callback(self: *Self, new_len: usize, f: fn(*T) void) void {
            for(self.as_slice_mut()[new_len..]) |*elem| {
                f(elem);
            }

            self.truncate(new_len);
        }

        pub fn clear(self: *Self) void {
            self.truncate(0);
        }

        pub fn clear_with_callback(self: *Self, f: fn(*T) void) void {
            self.truncate_with_callback(0, f);
        }

        pub fn retain(self: *Self, f: fn(*T) bool) void {
            var self_len = self.len();

            var del: usize = 0;

            var i: usize = 0;

            while(i < self_len): ({i += 1;}) {
                if (!f(&self.array[i])) {
                    del += 1;
                } else if (del > 0) {
                    self.swap(i - del, i);
                }
            }

            if (del > 0) {
                var drainit = self.drain(self_len - del, self_len);
                drainit.deinit();
            }
        }

        /// Set's the length of the ArrayVec.
        /// This changes the `meaning` of valid elements in the array.
        pub fn set_len(self: *Self, new_len: usize) void {
            debug.assert(new_len <= self.capacity());
            self.length = new_len;
        }

        pub fn try_extend_from_slice(self: *Self, other: []T) !void {
            if (self.remaining_capacity() < other.len) {
                return ArrayError.CapacityError;
            }

            var self_len = self.len();
            var other_len = other.len;

            mem.copy(T, self.array[self_len..], other);

            self.set_len(self_len + other_len);
        }

        pub fn drain(self: *Self, start: usize, end: usize) Drain(T, SIZE) {
            debug.assert(start < end);
            debug.assert(end <= self.len());
            return Drain(T, SIZE).new(self, start, end);
        }

        pub fn into_inner(self: Self) [SIZE]T {
            return self.array;
        }

        pub fn dispose(self: Self) void {
            self.clear();
        }

        pub fn as_slice(self: Self) []const T {
            return self.array[0..self.len()];
        }

        pub fn as_slice_mut(self: *Self) []T {
            return self.array[0..self.len()];
        }

        /// Returns an iterator that yields pointers
        /// to the initialized part of the array.
        ///
        /// # Safety
        /// Do *NOT* create an iterator,
        /// and perform write actions onto the array
        /// before using the iterator.
        fn iter(self: *const Self) Iter(T, SIZE) {
           return Iter(T, SIZE).new(self);
        }
        
        /// Returns an iterator that yields mutable pointers
        /// to the initialized part of the array.
        ///
        /// # Safety
        /// Do *NOT* create an iterator,
        /// and perform write actions onto the array
        /// before using the iterator.
        fn iter_mut(self: *Self) IterMut(T, SIZE) {
            return IterMut(T, SIZE).new(self);
        }

        fn into_iter(self: Self) IntoIter(T, SIZE) {
            return IntoIter(T, SIZE).new(self);
        }
    };
}

fn compile_error_if(comptime condition: bool, comptime msg: []const u8) void {
    if(condition) {
        @compileError(msg);
    }
}

fn __iter__(comptime Item: type, comptime Vec: type) type {
    // `Item` should be a pointer.
    // `Vec` should be of type *ArrayVec(Item, N) OR *const ArrayVec(Item, N).
    comptime {
        compile_error_if(
            !std.meta.trait.is(builtin.TypeId.Pointer)(Item),
            "Expected a Pointer for `Item`. Found `" ++ @typeName(Item) ++ "`."
        );

        const item_name = switch (@typeInfo(Item)) {
            builtin.TypeId.Pointer => |ptr| @typeName(ptr.child),
            else => unreachable
        };

        const name = switch (std.meta.trait.isConstPtr(Vec)) {
            true => "*const ArrayVec(" ++ item_name,
            else => "*ArrayVec(" ++ item_name,
        };

        compile_error_if(
            !std.mem.eql(u8, name, @typeName(Vec)[0..name.len]),
            "Expected type `*const ArrayVec` or `*ArrayVec`. Found `" ++ @typeName(Vec) ++ "`."
        );
    }

    return struct {
        array: Vec,
        index: usize,

        const Self = @This();

        fn new(arrayvec: Vec) Self {
            return  Self { .array = arrayvec, .index = comptime_int(0) };
        }
        
        fn next(self: *Self) ?Item {
            if (self.index < self.array.len()) {
                var elem = &self.array.array[self.index];
                self.index += 1;
                return elem;
            } else {
                return null;
            }
        }
    };
}

fn Iter(comptime T: type, comptime SIZE: usize) type {
    return __iter__(*const T, *const ArrayVec(T, SIZE));
}

fn IterMut(comptime T: type, comptime SIZE: usize) type {
    return __iter__(*T, *ArrayVec(T, SIZE));
}

fn IntoIter(comptime T: type, comptime SIZE: usize) type {
    return struct {
        array: ArrayVec(T, SIZE),
        index: usize,

        const Self = @This();

        fn new(arrayvec: ArrayVec(T, SIZE)) Self {
            return Self { .array = arrayvec, .index = comptime_int(0) };
        }

        fn next(self: *Self) ?T {
            if (self.index < self.array.len()) {
                var elem = self.array.array[self.index];
                self.index += 1;
                return elem;
            } else {
                return null;
            }
        }
   };
}

pub fn Drain(comptime T: type, comptime SIZE: usize) type {
    return struct {
        array: *ArrayVec(T, SIZE),
        real_start: usize,
        start: usize,
        end: usize,

        const Self = @This();

        fn new(arrayvec: *ArrayVec(T, SIZE), start_param: usize, end_param: usize) Self {
            return Self { .array = arrayvec, .real_start = start_param, .start = start_param, .end = end_param };
        }

        pub fn next(self: *Self) ?T {
            if (self.start < self.end) {
                var elem = self.array.array[self.start];
                self.start += 1;
                return elem;
            } else {
                return null;
            }
        }

        fn deinit(self: *Self) void {
            // First continue iterating self.
            // then memmove the tail back to where it belongs.
            while(self.next()) |_| {}

            var len: usize = 0;
            var self_len = self.array.len();


            for(self.array.as_slice_mut()[self.real_start..]) |*b, i| {
                if (self.end + i >= self_len) { break; }
                b.* = self.array.array[self.end + i];
                len += 1;
            }

            self.array.set_len(self.real_start + len);
        }
    };
}

test "const basic functions" {
    comptime {
        var arrayvec = ArrayVec(i32, 10).new();
        debug.assert(arrayvec.len() == 0);
        debug.assert(arrayvec.capacity() == 10);
    }
}

test "const iter" {
    comptime {
        var arrayvec = ArrayVec(i32, 10).new();
        
        arrayvec.push(10);
        arrayvec.push(20);

        var iter = arrayvec.iter();
        debug.assert(iter.next().?.* == 10);
        debug.assert(iter.next().?.* == 20);
        debug.assert(iter.next() == null);

        var slice = arrayvec.as_slice();

        debug.assert(mem.eql(i32, slice, [1]i32{10} ++ [1]i32{20}));
    }
}

test "const iter mut" {
    comptime {
        var arrayvec = ArrayVec(i32, 10).new();
        
        arrayvec.push(10);
        arrayvec.push(20);

        var iter = arrayvec.iter_mut();
        
        while(iter.next()) |item| {
            item.* *= 2;
        }
        
        var iter2 = arrayvec.iter();
        debug.assert(iter2.next().?.* == 20);
        debug.assert(iter2.next().?.* == 40);
        debug.assert(iter2.next() == null);
        
        debug.assert(arrayvec.pop().? == 40);
        debug.assert(arrayvec.pop().? == 20);
        debug.assert(arrayvec.pop() == null);
        debug.assert(arrayvec.is_empty());
    }
}

test "const into iter" {
    comptime {
        var arrayvec = ArrayVec(i32, 10).new();
        
        arrayvec.push(10);
        arrayvec.push(20);

        var iter = arrayvec.into_iter();
        
        debug.assert(iter.next().? == 10);
        debug.assert(iter.next().? == 20);
        debug.assert(iter.next() == null);

    }
}


test "const drain" {
    comptime {
        var arrayvec = ArrayVec(i32, 10).new();
        var array = [7]i32 {0, 1, 2, 3, 4, 5, 6};
        _ = arrayvec.try_extend_from_slice(&array) catch unreachable;

        debug.assert(arrayvec.len() == 7);
        {
            var drain_first = arrayvec.drain(0, 1);
            {
                defer drain_first.deinit();
                debug.assert(drain_first.next().? == 0);
                debug.assert(drain_first.next() == null);
            }

            debug.assert(arrayvec.len() == 6);
            var array_after_drain_first = [6]i32 {1, 2, 3, 4, 5, 6};
            debug.assert(mem.eql(i32, arrayvec.as_slice(), &array_after_drain_first));
        }
        {
            var drain = arrayvec.drain(2, 5);
            {
                defer drain.deinit();
                debug.assert(drain.next().? == 3);
                debug.assert(drain.next().? == 4);
                debug.assert(drain.next().? == 5);
                debug.assert(drain.next() == null);
            }

            debug.assert(arrayvec.len() == 3);
            var array_after_drain = [3]i32 {1, 2, 6};
            debug.assert(mem.eql(i32, arrayvec.as_slice(), &array_after_drain));
        }
        
        {
            var drain_last = arrayvec.drain(2, 3);
            {
                defer drain_last.deinit();
                debug.assert(drain_last.next().? == 6);
                debug.assert(drain_last.next() == null);
            }
            debug.assert(arrayvec.len() == 2);
            var array_after_drain_last = [2]i32 {1, 2};
            debug.assert(mem.eql(i32, arrayvec.as_slice(), &array_after_drain_last));
        }
    }
}

test "const remove" {
    comptime {
        var arrayvec = ArrayVec(i32, 10).new();
        var array = [6]i32 {1, 2, 3, 4, 5, 6};
        _ = arrayvec.try_extend_from_slice(&array) catch unreachable;

        var removed = arrayvec.remove(3);
        debug.assert(removed == 4);

        var array_after_remove = [5]i32 {1, 2, 3, 5, 6};
        debug.assert(mem.eql(i32, arrayvec.as_slice(), &array_after_remove));
    }
}

test "const retain" {
    comptime {

        const bigger_than_5 = struct { fn bigger_than_5(x: *i32) bool { return x.* > 5;} }.bigger_than_5;

        var arrayvec = ArrayVec(i32, 10).new();
        var array = [6]i32 {1, 2, 3, 4, 5, 6};
        _ = arrayvec.try_extend_from_slice(&array) catch unreachable;

        arrayvec.retain(bigger_than_5);

        debug.assert(arrayvec.len() == 1);

        var array_after_retain = [1]i32 { 6 };
        debug.assert(mem.eql(i32, arrayvec.as_slice(), &array_after_retain));
    }
}
