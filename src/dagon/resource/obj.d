/*
Copyright (c) 2017-2024 Timur Gafarov, Tynuk

Boost Software License - Version 1.0 - August 17th, 2003
Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module dagon.resource.obj;

import std.stdio;
import std.string;
import std.format;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.core.stream;
import dlib.math.vector;
import dlib.geometry.triangle;
import dlib.filesystem.filesystem;
import dlib.filesystem.stdfs;
import dlib.container.array;
import dlib.container.dict;
import dlib.text.str;

import dagon.core.bindings;
import dagon.resource.asset;
import dagon.graphics.mesh;

struct ObjFace
{
    uint[3] v;
    uint[3] t;
    uint[3] n;
    
    this(uint v1, uint v2, uint v3,
         uint t1, uint t2, uint t3,
         uint n1, uint n2, uint n3)
    {
        v[0] = v1;
        v[1] = v2;
        v[2] = v3;
        
        t[0] = t1;
        t[1] = t2;
        t[2] = t3;
        
        n[0] = n1;
        n[1] = n2;
        n[2] = n3;
    }
}

class OBJAsset: Asset
{
    Mesh mesh;
    Dict!(Mesh, string) groupMesh;

    this(Owner o)
    {
        super(o);
        groupMesh = dict!(Mesh, string);
    }

    ~this()
    {
        release();
        groupMesh.free();
    }

    override bool loadThreadSafePart(string filename, InputStream istrm, ReadOnlyFileSystem fs, AssetManager mngr)
    {
        uint numVerts = 0;
        uint numNormals = 0;
        uint numTexcoords = 0;
        uint numFaces = 0;
        
        string fileStr = readText(istrm);
        
        foreach(line; lineSplitter(fileStr))
        {
            if (line.startsWith("v "))
                numVerts++;
            else if (line.startsWith("vn "))
                numNormals++;
            else if (line.startsWith("vt "))
                numTexcoords++;
            else if (line.startsWith("f "))
                numFaces++;
            else if (line.startsWith("mtllib "))
                writeln("Warning: OBJ file \"", filename, "\" contains materials, but Dagon doesn't support them");
        }
        
        Vector3f[] tmpVertices;
        Vector3f[] tmpNormals;
        Vector2f[] tmpTexcoords;
        Array!ObjFace tmpFaces;
        
        bool needGenNormals = false;
        
        if (!numVerts)
            writeln("Warning: OBJ file \"", filename, "\" has no vertices");
        if (!numNormals)
        {
            writeln("Warning: OBJ file \"", filename, "\" has no normals (they will be generated)");
            numNormals = numVerts;
            needGenNormals = true;
        }
        if (!numTexcoords)
        {
            writeln("Warning: OBJ file \"", filename, "\" has no texcoords");
            numTexcoords = numVerts;
        }
        
        if (numVerts)
            tmpVertices = New!(Vector3f[])(numVerts);
        if (numNormals)
            tmpNormals = New!(Vector3f[])(numNormals);
        if (numTexcoords)
            tmpTexcoords = New!(Vector2f[])(numTexcoords);
        if (numFaces)
            tmpFaces.reserve(numFaces);
        
        tmpVertices[] = Vector3f(0, 0, 0);
        tmpNormals[] = Vector3f(0, 0, 0);
        tmpTexcoords[] = Vector2f(0, 0);
        
        string currentGroup;
        
        float x, y, z;
        uint v1, v2, v3, v4;
        uint t1, t2, t3, t4;
        uint n1, n2, n3, n4;
        uint vi = 0;
        uint ni = 0;
        uint ti = 0;
        
        String tmpStr;
        
        size_t groupFaceSliceStart = 0;
        size_t groupFaceSliceLength;
        
        foreach(line; lineSplitter(fileStr))
        {
            if (line.startsWith("v "))
            {
                if (formattedRead(line, "v %s %s %s", &x, &y, &z))
                {
                    tmpVertices[vi] = Vector3f(x, y, z);
                    vi++;
                }
            }
            else if (line.startsWith("vn"))
            {
                if (formattedRead(line, "vn %s %s %s", &x, &y, &z))
                {
                    tmpNormals[ni] = Vector3f(x, y, z);
                    ni++;
                }
            }
            else if (line.startsWith("vt"))
            {
                if (formattedRead(line, "vt %s %s", &x, &y))
                {
                    tmpTexcoords[ti] = Vector2f(x, -y);
                    ti++;
                }
            }
            else if (line.startsWith("vp"))
            {
            }
            else if (line.startsWith("g "))
            {
                if (currentGroup != "")
                {
                    groupMesh[currentGroup] = fillMesh(
                        tmpFaces.data[groupFaceSliceStart..$],
                        tmpTexcoords,
                        tmpNormals,
                        tmpVertices,
                        needGenNormals
                    );
                }
                
                groupFaceSliceStart = tmpFaces.length;
                
                if (formattedRead(line, "g %s", &currentGroup)) { }
                else
                    assert(0);
            }
            else if (line.startsWith("f "))
            {
                tmpStr.free();
                tmpStr = String(line);
                
                ObjFace face;
                
                if (sscanf(tmpStr.ptr, "f %u/%u/%u %u/%u/%u %u/%u/%u %u/%u/%u", &v1, &t1, &n1, &v2, &t2, &n2, &v3, &t3, &n3, &v4, &t4, &n4) == 12)
                {
                    face = ObjFace(v1-1, v2-1, v3-1, t1-1, t2-1, t3-1, n1-1, n2-1, n3-1);
                    tmpFaces.insertBack(face);
                    
                    face = ObjFace(v1-1, v3-1, v4-1, t1-1, t3-1, t4-1, n1-1, n3-1, n4-1);
                    tmpFaces.insertBack(face);
                }
                else if (sscanf(tmpStr.ptr, "f %u/%u/%u %u/%u/%u %u/%u/%u", &v1, &t1, &n1, &v2, &t2, &n2, &v3, &t3, &n3) == 9)
                {
                    face = ObjFace(v1-1, v2-1, v3-1, t1-1, t2-1, t3-1, n1-1, n2-1, n3-1);
                    tmpFaces.insertBack(face);
                }
                else if (sscanf(tmpStr.ptr, "f %u//%u %u//%u %u//%u %u//%u", &v1, &n1, &v2, &n2, &v3, &n3, &v4, &n4) == 8)
                {
                    face = ObjFace(v1-1, v2-1, v3-1, 0, 0, 0, n1-1, n2-1, n3-1);
                    tmpFaces.insertBack(face);
                    
                    face = ObjFace(v1-1, v3-1, v4-1, 0, 0, 0, n1-1, n3-1, n4-1);
                    tmpFaces.insertBack(face);
                } 
                else if (sscanf(tmpStr.ptr, "f %u/%u %u/%u %u/%u", &v1, &t1, &v2, &t2, &v3, &t3) == 6)
                {
                    face = ObjFace(v1-1, v2-1, v3-1, t1-1, t2-1, t3-1, 0, 0, 0);
                    tmpFaces.insertBack(face);
                }
                else if (sscanf(tmpStr.ptr, "f %u//%u %u//%u %u//%u", &v1, &n1, &v2, &n2, &v3, &n3) == 6)
                {
                    face = ObjFace(v1-1, v2-1, v3-1, 0, 0, 0, n1-1, n2-1, n3-1);
                    tmpFaces.insertBack(face);
                }
                else if (sscanf(tmpStr.ptr, "f %u %u %u %u", &v1, &v2, &v3, &v4) == 4)
                {
                    face = ObjFace(v1-1, v2-1, v3-1, 0, 0, 0, 0, 0, 0);
                    tmpFaces.insertBack(face);
                    
                    face = ObjFace(v1-1, v3-1, v4-1, 0, 0, 0, 0, 0, 0);
                    tmpFaces.insertBack(face);
                }
                else if (sscanf(tmpStr.ptr, "f %u %u %u", &v1, &v2, &v3) == 3)
                {
                    face = ObjFace(v1-1, v2-1, v3-1, 0, 0, 0, 0, 0, 0);
                    tmpFaces.insertBack(face);
                }
                else
                {
                    writeln("Warning: OBJ file \"", filename, "\" contains one or more N-gons, but Dagon doesn't support them. Please, use only triangles or quads");
                }
            }
        }
        
        // Create last group mesh
        if (currentGroup != "")
        {
            groupMesh[currentGroup] = fillMesh(
                tmpFaces.data[groupFaceSliceStart..$],
                tmpTexcoords,
                tmpNormals,
                tmpVertices,
                needGenNormals
            );
        }
        
        writeln("Mesh...");
        mesh = fillMesh(
            tmpFaces.data,
            tmpTexcoords,
            tmpNormals,
            tmpVertices,
            needGenNormals);
        
        Delete(fileStr);
        tmpStr.free();
        
        if (tmpVertices.length)
            Delete(tmpVertices);
        if (tmpNormals.length)
            Delete(tmpNormals);
        if (tmpTexcoords.length)
            Delete(tmpTexcoords);
        tmpFaces.free();
        
        return true;
    }

    Mesh fillMesh(
        ObjFace[] faces,
        Vector2f[] tmpTexcoords,
        Vector3f[] tmpNormals,
        Vector3f[] tmpVertices,
        bool needGenNormals)
    {
        auto m = New!Mesh(this);
        
        m.indices = New!(uint[3][])(faces.length);
        uint numUniqueVerts = cast(uint)m.indices.length * 3;
        m.vertices = New!(Vector3f[])(numUniqueVerts);
        m.normals = New!(Vector3f[])(numUniqueVerts);
        m.texcoords = New!(Vector2f[])(numUniqueVerts);
        
        uint index = 0;
        
        foreach(i, ref ObjFace f; faces)
        {
            if (tmpVertices.length)
            {
                m.vertices[index] = tmpVertices[f.v[0]];
                m.vertices[index+1] = tmpVertices[f.v[1]];
                m.vertices[index+2] = tmpVertices[f.v[2]];
            }
            else
            {
                m.vertices[index] = Vector3f(0, 0, 0);
                m.vertices[index+1] = Vector3f(0, 0, 0);
                m.vertices[index+2] = Vector3f(0, 0, 0);
            }
            
            if (tmpNormals.length)
            {
                m.normals[index] = tmpNormals[f.n[0]];
                m.normals[index+1] = tmpNormals[f.n[1]];
                m.normals[index+2] = tmpNormals[f.n[2]];
            }
            else
            {
                m.normals[index] = Vector3f(0, 0, 0);
                m.normals[index+1] = Vector3f(0, 0, 0);
                m.normals[index+2] = Vector3f(0, 0, 0);
            }
            
            if (tmpTexcoords.length)
            {
                m.texcoords[index] = tmpTexcoords[f.t[0]];
                m.texcoords[index+1] = tmpTexcoords[f.t[1]];
                m.texcoords[index+2] = tmpTexcoords[f.t[2]];
            }
            else
            {
                m.texcoords[index] = Vector2f(0, 0);
                m.texcoords[index+1] = Vector2f(0, 0);
                m.texcoords[index+2] = Vector2f(0, 0);
            }
            
            m.indices[i][0] = index;
            m.indices[i][1] = index + 1;
            m.indices[i][2] = index + 2;
            
            index += 3;
        }
        
        
        if (needGenNormals)
            m.generateNormals();
        
        m.calcBoundingBox();
        
        m.dataReady = true;
        
        return m;
    }

    override bool loadThreadUnsafePart()
    {
        mesh.prepareVAO();
        foreach(name, m; groupMesh)
        {
            m.prepareVAO();
        }
        return true;
    }

    override void release()
    {
        clearOwnedObjects();
    }
}
