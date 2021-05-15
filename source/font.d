module font;

struct BitfontLetter {
    uint width;
    uint offsetX, offsetY;
    uint texX, texY, texWidth, texHeight;
}

struct AsciiBitfont {
    uint height;
    BitfontLetter[256] letters;
    this(string xmlFont) {
        ulong pos = 0;
        while (pos < xmlFont.length) {
            if(xmlFont[pos] == '<') {
                pos++;
                if (xmlFont[pos .. pos + 5] == "Font ") {
                    pos += 5;
                    import std.conv : to;
                    while (xmlFont[pos .. pos + 7] != "height=") {
                        pos++;
                    }
                    pos += 8;
                    ulong endPos = pos;
                    while (xmlFont[endPos] != '"') {
                        endPos++;
                    }
                    height = to!uint(xmlFont[pos .. endPos]);
                    pos = endPos + 2;
                }
                if (xmlFont[pos .. pos + 5] == "Char ") {
                    pos += 5;
                    char code;
                    uint width;
                    uint offsetX, offsetY;
                    uint texX, texY, texWidth, texHeight;
                    import std.conv : to;
                    while (xmlFont[pos] != '>') {
                        if (xmlFont[pos .. pos + 6] == "width=") {
                            pos += 7;
                            ulong endPos = pos;
                            while (xmlFont[endPos] != '"') {
                                endPos++;
                            }
                            width = to!uint(xmlFont[pos .. endPos]);
                            pos = endPos + 2;
                        }
                        if (xmlFont[pos .. pos + 7] == "offset=") {
                            pos += 8;
                            ulong endPos = pos;
                            while (xmlFont[endPos] != ' ') {
                                endPos++;
                            }
                            offsetX = to!uint(xmlFont[pos .. endPos]);
                            pos = endPos + 1;

                            endPos = pos;
                            while (xmlFont[endPos] != '"') {
                                endPos++;
                            }
                            offsetY = to!uint(xmlFont[pos .. endPos]);
                            pos = endPos + 2;
                        }
                        if (xmlFont[pos .. pos + 5] == "rect=") {
                            pos += 6;
                            ulong endPos = pos;
                            while (xmlFont[endPos] != ' ') {
                                endPos++;
                            }
                            texX = to!uint(xmlFont[pos .. endPos]);
                            pos = endPos + 1;

                            endPos = pos;
                            while (xmlFont[endPos] != ' ') {
                                endPos++;
                            }
                            texY = to!uint(xmlFont[pos .. endPos]);
                            pos = endPos + 1;
                            
                            endPos = pos;
                            while (xmlFont[endPos] != ' ') {
                                endPos++;
                            }
                            texWidth = to!uint(xmlFont[pos .. endPos]);
                            pos = endPos + 1;
                            
                            endPos = pos;
                            while (xmlFont[endPos] != '"') {
                                endPos++;
                            }
                            texHeight = to!uint(xmlFont[pos .. endPos]);
                            pos = endPos + 2;
                        }
                        if (xmlFont[pos .. pos + 5] == "code=") {
                            pos += 6;
                            ulong endPos = pos;
                            while (xmlFont[endPos] != '"') {
                                endPos++;
                            }
                            code = xmlFont[pos];
                            if (xmlFont[pos .. endPos] == "&quot;") {
                                code = '"';
                            }
                            if (xmlFont[pos .. endPos] == "&amp;") {
                                code = '&';
                            }
                            if (xmlFont[pos .. endPos] == "&lt;") {
                                code = '<';
                            }
                            pos = endPos + 2;
                        }
                    }
                    letters[code].width = width;
                    letters[code].offsetX = offsetX;
                    letters[code].offsetY = offsetY;
                    letters[code].texX = texX;
                    letters[code].texY = texY;
                    letters[code].texWidth = texWidth;
                    letters[code].texHeight = texHeight;
                }
            }
            pos++;
        }
    }
}