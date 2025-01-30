/*
Copyright (c) 2025 Timur Gafarov

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
module dagon.graphics.billboard;

import std.math;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import dlib.math.utils;

import dagon.core.bindings;
import dagon.graphics.drawable;
import dagon.graphics.state;
import dagon.graphics.mesh;

/*
 * Perspective-invariant screen aligned quad
 */
class Billboard: Owner, Drawable
{
    Vector2f[4] vertices;
    Vector2f[4] texcoords;
    uint[3][2] indices;

    GLuint vao = 0;
    GLuint vbo = 0;
    GLuint tbo = 0;
    GLuint eao = 0;
    
    float rotation = 0.0f;
    
    this(Owner owner)
    {
        super(owner);
        
        vertices[0] = Vector2f(-0.5f, 0.5f);
        vertices[1] = Vector2f(-0.5f, -0.5f);
        vertices[2] = Vector2f(0.5f, -0.5f);
        vertices[3] = Vector2f(0.5f, 0.5f);

        texcoords[0] = Vector2f(0, 0);
        texcoords[1] = Vector2f(0, 1);
        texcoords[2] = Vector2f(1, 1);
        texcoords[3] = Vector2f(1, 0);

        indices[0][0] = 0;
        indices[0][1] = 1;
        indices[0][2] = 2;

        indices[1][0] = 0;
        indices[1][1] = 2;
        indices[1][2] = 3;

        glGenBuffers(1, &vbo);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, vertices.length * float.sizeof * 2, vertices.ptr, GL_STATIC_DRAW);

        glGenBuffers(1, &tbo);
        glBindBuffer(GL_ARRAY_BUFFER, tbo);
        glBufferData(GL_ARRAY_BUFFER, texcoords.length * float.sizeof * 2, texcoords.ptr, GL_STATIC_DRAW);

        glGenBuffers(1, &eao);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, eao);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.length * uint.sizeof * 3, indices.ptr, GL_STATIC_DRAW);

        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, eao);

        glEnableVertexAttribArray(VertexAttrib.Vertices);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glVertexAttribPointer(VertexAttrib.Vertices, 2, GL_FLOAT, GL_FALSE, 0, null);

        glEnableVertexAttribArray(VertexAttrib.Texcoords);
        glBindBuffer(GL_ARRAY_BUFFER, tbo);
        glVertexAttribPointer(VertexAttrib.Texcoords, 2, GL_FLOAT, GL_FALSE, 0, null);

        glBindVertexArray(0);
    }
    
    ~this()
    {
        glDeleteVertexArrays(1, &vao);
        glDeleteBuffers(1, &vbo);
        glDeleteBuffers(1, &tbo);
        glDeleteBuffers(1, &eao);
    }
    
    void render(GraphicsState* state)
    {
        GraphicsState stateLocal = *state;
        
        Vector3f position = state.modelMatrix.translation;
        Vector3f scaling = state.modelMatrix.scaling;
        
        Matrix4x4f modelViewMatrix =
            state.viewMatrix *
            translationMatrix(position) *
            state.invViewRotationMatrix *
            rotationMatrix(Axis.z, rotation) *
            scaleMatrix(Vector3f(scaling.x, scaling.y, 1.0f));
        
        stateLocal.modelViewMatrix = modelViewMatrix;
        stateLocal.prevModelViewMatrix = modelViewMatrix;
        
        if (stateLocal.shader)
        {
            stateLocal.shader.bindParameters(&stateLocal);
        }
        
        glBindVertexArray(vao);
        glDrawElements(GL_TRIANGLES, cast(uint)indices.length * 3, GL_UNSIGNED_INT, cast(void*)0);
        glBindVertexArray(0);
        
        if (stateLocal.shader)
        {
            stateLocal.shader.unbindParameters(&stateLocal);
        }
    }
}
