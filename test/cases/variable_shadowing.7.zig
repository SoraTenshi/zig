pub fn main() void {
    var i = 0;
    if (true) |i| {}
}

// error
//
// :3:16: error: redeclaration of local variable 'i'
// :2:9: note: previous declaration here
