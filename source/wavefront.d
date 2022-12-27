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
        size_t normalCount = 0;
        size_t uvCount = 0;
        size_t indexCount = 0;
        size_t pos = 0;
        while (pos < wavefrontModel.length - 1) {
            if (wavefrontModel[pos .. pos + 2] == "v ") {
                vertexCount++;
                pos += 2;
            } else if (wavefrontModel[pos .. pos + 2] == "vn") {
                normalCount++;
                pos += 3;
            } else if (wavefrontModel[pos .. pos + 2] == "vt") {
                uvCount++;
                pos += 3;
            } else if (wavefrontModel[pos .. pos + 2] == "f ") {
                indexCount++;
                pos += 2;
            } else {
                pos++;
            }
        }
        vertices = Vector!float(vertexCount * 3);
        normals = Vector!float(normalCount * 3);
        uvs = Vector!float(uvCount * 2);
        indicesVertices = Vector!uint(indexCount * 3);
        indicesNormals = Vector!uint(indexCount * 3);
        indicesUvs = Vector!uint(indexCount * 3);
        pos = 0;
        size_t vertexId = 0;
        size_t normalId = 0;
        size_t uvId = 0;
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
                while (wavefrontModel[pos + numberLength] != '\n' && wavefrontModel[pos + numberLength] != '\r') {
                    numberLength++;
                }
                vertices[vertexId] = to!float(wavefrontModel[pos .. pos + numberLength]);
                //writeln("v: ", vertices[vertexId]);
                vertexId++;
                pos += numberLength + 1;
            } else if (wavefrontModel[pos .. pos + 2] == "vn") {
                pos += 3;

                size_t numberLength = 0;
                while (wavefrontModel[pos + numberLength] != ' ') {
                    numberLength++;
                }
                normals[normalId] = to!float(wavefrontModel[pos .. pos + numberLength]);
                //writeln("v: ", vertices[vertexId]);
                normalId++;
                pos += numberLength + 1;

                numberLength = 0;
                while (wavefrontModel[pos + numberLength] != ' ') {
                    numberLength++;
                }
                normals[normalId] = to!float(wavefrontModel[pos .. pos + numberLength]);
                //writeln("v: ", vertices[vertexId]);
                normalId++;
                pos += numberLength + 1;

                numberLength = 0;
                while (wavefrontModel[pos + numberLength] != '\n' && wavefrontModel[pos + numberLength] != '\r') {
                    numberLength++;
                }
                normals[normalId] = to!float(wavefrontModel[pos .. pos + numberLength]);
                //writeln("v: ", vertices[vertexId]);
                normalId++;
                pos += numberLength + 1;
            } else if (wavefrontModel[pos .. pos + 2] == "vt") {
                pos += 3;

                size_t numberLength = 0;
                while (wavefrontModel[pos + numberLength] != ' ') {
                    numberLength++;
                }
                uvs[uvId] = to!float(wavefrontModel[pos .. pos + numberLength]);
                //writeln("v: ", vertices[vertexId]);
                uvId++;
                pos += numberLength + 1;

                numberLength = 0;
                while (wavefrontModel[pos + numberLength] != '\n' && wavefrontModel[pos + numberLength] != '\r') {
                    numberLength++;
                }
                uvs[uvId] = to!float(wavefrontModel[pos .. pos + numberLength]);
                //writeln("v: ", vertices[vertexId]);
                uvId++;
                pos += numberLength + 1;
            } else if (wavefrontModel[pos .. pos + 2] == "f ") {
                pos += 2;

                size_t numberLength = 0;
                while (wavefrontModel[pos + numberLength] != '/') {
                    numberLength++;
                }
                indicesVertices[indexId] = to!uint(wavefrontModel[pos .. pos + numberLength]) - 1;
                pos += numberLength + 1;

                numberLength = 0;
                while (wavefrontModel[pos + numberLength] != '/') {
                    numberLength++;
                }
                indicesUvs[indexId] = to!uint(wavefrontModel[pos .. pos + numberLength]) - 1;
                pos += numberLength + 1;

                numberLength = 0;
                while (wavefrontModel[pos + numberLength] != ' ') {
                    numberLength++;
                }
                indicesNormals[indexId] = to!uint(wavefrontModel[pos .. pos + numberLength]) - 1;
                pos += numberLength + 1;

                //writeln("f: ", indicesVertices[indexId]);
                indexId++;
                /*while (wavefrontModel[pos] != ' ') {
                    pos++;
                }*/
                //pos++;

                numberLength = 0;
                while (wavefrontModel[pos + numberLength] != '/') {
                    numberLength++;
                }
                indicesVertices[indexId] = to!uint(wavefrontModel[pos .. pos + numberLength]) - 1;
                pos += numberLength + 1;

                numberLength = 0;
                while (wavefrontModel[pos + numberLength] != '/') {
                    numberLength++;
                }
                indicesUvs[indexId] = to!uint(wavefrontModel[pos .. pos + numberLength]) - 1;
                pos += numberLength + 1;

                numberLength = 0;
                while (wavefrontModel[pos + numberLength] != ' ') {
                    numberLength++;
                }
                indicesNormals[indexId] = to!uint(wavefrontModel[pos .. pos + numberLength]) - 1;
                pos += numberLength + 1;

                //writeln("f: ", indicesVertices[indexId]);
                indexId++;
                /*while (wavefrontModel[pos] != ' ') {
                    pos++;
                }*/
                //pos++;

                numberLength = 0;
                while (wavefrontModel[pos + numberLength] != '/') {
                    numberLength++;
                }
                indicesVertices[indexId] = to!uint(wavefrontModel[pos .. pos + numberLength]) - 1;
                pos += numberLength + 1;

                numberLength = 0;
                while (wavefrontModel[pos + numberLength] != '/') {
                    numberLength++;
                }
                indicesUvs[indexId] = to!uint(wavefrontModel[pos .. pos + numberLength]) - 1;
                pos += numberLength + 1;

                numberLength = 0;
                while (wavefrontModel[pos + numberLength] != '\n' && wavefrontModel[pos + numberLength] != '\r') {
                    numberLength++;
                }
                indicesNormals[indexId] = to!uint(wavefrontModel[pos .. pos + numberLength]) - 1;
                pos += numberLength + 1;

                //writeln("f: ", indicesVertices[indexId]);
                indexId++;
            } else {
                pos++;
            }
        }
    }
}