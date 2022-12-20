module wavefront;

import functions;
import utils;

struct WavefrontModel {
    Vector!float vertices;
    Vector!float normals;
    Vector!float uvs;
    Vector!uint indicesVertices;
    Vector!uint indicesNormals;
    Vector!uint indicesUvs;
    this(string wavefrontModel) {
        size_t vertexCount = 0;
        size_t indexCount = 0;
        size_t pos = 0;
        while (pos < wavefrontModel.length - 1) {
            if (wavefrontModel[pos .. pos + 2] == "v ") {
                vertexCount++;
                pos += 2;
            } else if (wavefrontModel[pos .. pos + 2] == "f ") {
                indexCount++;
                pos += 2;
            } else {
                pos++;
            }
        }
        vertices = Vector!float(vertexCount * 3);
        indicesVertices = Vector!uint(indexCount * 3);
        pos = 0;
        size_t vertexId = 0;
        size_t indexId = 0;
        while (pos < wavefrontModel.length - 1) {
            if (wavefrontModel[pos .. pos + 2] == "v ") {
                pos += 2;

                size_t numberLength = 0;
                while (wavefrontModel[pos + numberLength] != ' ') {
                    numberLength++;
                }
                vertices[vertexId] = to!float(wavefrontModel[pos .. pos + numberLength]);
                //writeln("v: ", vertices[vertexId]);
                vertexId++;
                pos += numberLength + 1;

                numberLength = 0;
                while (wavefrontModel[pos + numberLength] != ' ') {
                    numberLength++;
                }
                vertices[vertexId] = to!float(wavefrontModel[pos .. pos + numberLength]);
                //writeln("v: ", vertices[vertexId]);
                vertexId++;
                pos += numberLength + 1;

                numberLength = 0;
                while (wavefrontModel[pos + numberLength] != '\n') {
                    numberLength++;
                }
                vertices[vertexId] = to!float(wavefrontModel[pos .. pos + numberLength]);
                //writeln("v: ", vertices[vertexId]);
                vertexId++;
                pos += numberLength + 1;
            } else if (wavefrontModel[pos .. pos + 2] == "f ") {
                pos += 2;

                size_t numberLength = 0;
                while (wavefrontModel[pos + numberLength] != '/') {
                    numberLength++;
                }
                indicesVertices[indexId] = to!uint(wavefrontModel[pos .. pos + numberLength]) - 1;
                //writeln("f: ", indicesVertices[indexId]);
                indexId++;
                pos += numberLength;
                while (wavefrontModel[pos] != ' ') {
                    pos++;
                }
                pos++;

                numberLength = 0;
                while (wavefrontModel[pos + numberLength] != '/') {
                    numberLength++;
                }
                indicesVertices[indexId] = to!uint(wavefrontModel[pos .. pos + numberLength]) - 1;
                //writeln("f: ", indicesVertices[indexId]);
                indexId++;
                pos += numberLength;
                while (wavefrontModel[pos] != ' ') {
                    pos++;
                }
                pos++;

                numberLength = 0;
                while (wavefrontModel[pos + numberLength] != '/') {
                    numberLength++;
                }
                indicesVertices[indexId] = to!uint(wavefrontModel[pos .. pos + numberLength]) - 1;
                //writeln("f: ", indicesVertices[indexId]);
                indexId++;
                pos += numberLength;
            } else {
                pos++;
            }
        }
    }
}