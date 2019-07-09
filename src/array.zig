const std = @import("std");
const builtin = @import("builtin");

const debug = std.debug;

/// An errorset for an ArrayVec
const ArrayError = error {
    CapacityError,
};

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
        pub fn len(self: *const Self) usize {
            return self.length;
        }

        /// Returns the capacity of the ArrayVec.
        pub fn capacity(self: *const Self) usize {
            return SIZE;
        }

        pub fn is_empty(self: *const Self) bool {
            return self.len() == 0;
        }

        /// Set's the length of the ArrayVec.
        /// This changes the `meaning` of valid elements in the array.
        pub fn set_len(self: *Self, new_len: usize) void {
            debug.assert(new_len <= self.capacity());
            self.length = new_len;
        }

        /// Pushes `element` onto the array.
        /// Panic's if the array was already full.
        fn push(self: *Self, element: T) void {
            self.try_push(element) catch unreachable;
        }

        /// Pushes `element` onto the array.
        /// If the array was already full,
        /// An error is returned.
        fn try_push(self: *Self, element: T) !void {
            if (self.len() < self.capacity()) {
                self.push_unchecked(element);
            } else {
                return ArrayError.CapacityError;
            }
        }

        /// Pushes `element` onto the array.
        /// This function does *NOT* boundscheck.
        fn push_unchecked(self: *Self, element: T) void {
            // Store the length in a variable for reuse.
            var self_len = self.len();

            debug.assert(self_len < self.capacity());
            self.array[self_len] = element;
            self.set_len(self_len + 1);
        }

        /// Remove the last element in the array and return it.
        fn pop(self: *Self) ?T {
            if (self.is_empty()) {
                return null;
            } else {
                const new_len = self.len() - 1;
                self.set_len(new_len);
                return self.array[new_len];
            }
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