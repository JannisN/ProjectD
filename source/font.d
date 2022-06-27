module font;

import utils;

struct BitfontLetter {
	uint width;
	uint offsetX, offsetY;
	uint texX, texY, texWidth, texHeight;
}

struct AsciiBitfont {
	uint height;
	BitfontLetter[256] letters;
	Vector!float createText(string text, float x, float y, float scale) {
		scale = scale * 0.01;
		Vector!float ret;
		ret.resize(24 * letters.length);
		uint offset = 0;
		uint offsetLine = 0;
		enum float eps = 0.001;
		foreach (i, char e; text) {
			ret[i * 24] = x + scale * (offset + letters[e].offsetX);
			ret[i * 24 + 1] = y + scale * (offsetLine + letters[e].offsetY);
			ret[i * 24 + 2] = letters[e].texX + eps;
			ret[i * 24 + 3] = letters[e].texY + eps;

			ret[i * 24 + 4] = x + scale * (offset + letters[e].offsetX + letters[e].texWidth);
			ret[i * 24 + 4 + 1] = y + scale * (offsetLine + letters[e].offsetY);
			ret[i * 24 + 4 + 2] = letters[e].texX + letters[e].texWidth - eps;
			ret[i * 24 + 4 + 3] = letters[e].texY + eps;

			ret[i * 24 + 8] = x + scale * (offset + letters[e].offsetX);
			ret[i * 24 + 8 + 1] = y + scale * (offsetLine + letters[e].offsetY + letters[e].texHeight);
			ret[i * 24 + 8 + 2] = letters[e].texX + eps;
			ret[i * 24 + 8 + 3] = letters[e].texY + letters[e].texHeight - eps;
			
			ret[i * 24 + 12] = x + scale * (offset + letters[e].offsetX);
			ret[i * 24 + 12 + 1] = y + scale * (offsetLine + letters[e].offsetY + letters[e].texHeight);
			ret[i * 24 + 12 + 2] = letters[e].texX + eps;
			ret[i * 24 + 12 + 3] = letters[e].texY + letters[e].texHeight - eps;

			ret[i * 24 + 16] = x + scale * (offset + letters[e].offsetX + letters[e].texWidth);
			ret[i * 24 + 16 + 1] = y + scale * (offsetLine + letters[e].offsetY);
			ret[i * 24 + 16 + 2] = letters[e].texX + letters[e].texWidth - eps;
			ret[i * 24 + 16 + 3] = letters[e].texY + eps;

			ret[i * 24 + 20] = x + scale * (offset + letters[e].offsetX + letters[e].texWidth);
			ret[i * 24 + 20 + 1] = y + scale * (offsetLine + letters[e].offsetY + letters[e].texHeight);
			ret[i * 24 + 20 + 2] = letters[e].texX + letters[e].texWidth - eps;
			ret[i * 24 + 20 + 3] = letters[e].texY + letters[e].texHeight - eps;
			
			offset += letters[e].width;
			if (e == '\n') {
				offsetLine += 12;
				offset = 0;
			}
		}
		return ret;
	}
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