/*
Copyright (c) 2024-2025 Timur Gafarov

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

module dagon.render.simple.shaders.simpleforward;

import std.stdio;
import std.math;
import std.algorithm;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import dlib.math.interpolation;
import dlib.image.color;
import dlib.text.str;

import dagon.core.bindings;
import dagon.graphics.entity;
import dagon.graphics.material;
import dagon.graphics.shader;
import dagon.graphics.state;
import dagon.graphics.light;

class SimpleForwardShader: Shader
{
    String vs, fs;

    this(Owner owner)
    {
        vs = Shader.load("data/__internal/shaders/SimpleForward/SimpleForward.vert.glsl");
        fs = Shader.load("data/__internal/shaders/SimpleForward/SimpleForward.frag.glsl");

        auto prog = New!ShaderProgram(vs, fs, this);
        super(prog, owner);
    }

    ~this()
    {
        vs.free();
        fs.free();
    }

    override void bindParameters(GraphicsState* state)
    {
        Material mat = state.material;
        
        setParameter("modelViewMatrix", state.modelViewMatrix);
        setParameter("projectionMatrix", state.projectionMatrix);
        setParameter("normalMatrix", state.normalMatrix);
        
        setParameter("opacity", mat.opacity * state.opacity);
        setParameter("textureScale", mat.textureScale);
        
        Light sun = mat.sun;
        if (sun is null && state.environment !is null)
            sun = state.environment.sun;
        
        Vector3f sunDirection = Vector3f(0.0f, 0.0f, 1.0f);
        Color4f sunColor = Color4f(1.0f, 1.0f, 1.0f, 1.0f);
        float sunEnergy = 1.0f;
        if (sun)
        {
            sunDirection = sun.directionAbsolute;
            sunColor = sun.color;
            sunEnergy = sun.energy;
        }
        
        Vector4f sunDirHg = Vector4f(sunDirection);
        sunDirHg.w = 0.0;
        setParameter("sunDirection", (sunDirHg * state.viewMatrix).xyz);
        setParameter("sunColor", sunColor);
        setParameter("sunEnergy", sunEnergy);
        setParameter("shaded", !mat.shadeless);
        setParameter("gloss", max(0.001f, 1.0f - mat.roughnessFactor));
        
        // Ambient
        if (state.environment)
        {
            setParameter("fogColor", state.environment.fogColor);
            setParameter("fogStart", state.environment.fogStart);
            setParameter("fogEnd", state.environment.fogEnd);
            setParameter("ambientColor", state.environment.ambientColor);
            setParameter("ambientEnergy", state.environment.ambientEnergy);
        }
        else
        {
            setParameter("fogColor", Color4f(0.5f, 0.5f, 0.5f, 1.0f));
            setParameter("fogStart", 0.0f);
            setParameter("fogEnd", 1000.0f);
            setParameter("ambientColor", Color4f(0.0f, 0.0f, 0.0f, 1.0f));
            setParameter("ambientEnergy", 1.0f);
        }
        
        // Diffuse
        glActiveTexture(GL_TEXTURE0);
        setParameter("diffuseTexture", cast(int)0);
        setParameter("diffuseVector", mat.baseColorFactor);
        if (mat.baseColorTexture)
        {
            mat.baseColorTexture.bind();
            setParameterSubroutine("diffuse", ShaderType.Fragment, "diffuseColorTexture");
        }
        else
        {
            glBindTexture(GL_TEXTURE_2D, 0);
            setParameterSubroutine("diffuse", ShaderType.Fragment, "diffuseColorValue");
        }

        super.bindParameters(state);
    }

    override void unbindParameters(GraphicsState* state)
    {
        super.unbindParameters(state);
        
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, 0);
        
        glActiveTexture(GL_TEXTURE0);
    }
}
