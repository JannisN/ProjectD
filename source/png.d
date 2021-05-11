module png;

import std.stdio;

private extern(C) char* stbi_load_from_memory(char*, int, int*, int*, int*, int);
//private extern(C) char* stbi_load(char*, int*, int*, int*, int);
private extern(C) void stbi_image_free(void*);

void pngtest(string data) {
    int x, y, n;
    char* content = stbi_load_from_memory(cast(char*) data.ptr, cast(int)data.length, &x, &y, &n, 0);
    //char* content = stbi_load(cast(char*) "E://repositories/ProjectD/views/free_pixel_regular_16test.PNG".ptr, &x, &y, &n, 0);
    writeln(x);
    writeln(y);
    writeln(n);
    foreach (i; 0..100) {
        write(cast(ubyte) *(content + i * 4 + 3));
        write(" ");
    }
    stbi_image_free(cast(void*) content);
}