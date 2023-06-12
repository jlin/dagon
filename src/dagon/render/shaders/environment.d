/*
Copyright (c) 2019-2023 Timur Gafarov

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

module dagon.render.shaders.environment;

import std.stdio;
import std.math;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import dlib.math.interpolation;
import dlib.image.color;
import dlib.text.str;

import dagon.core.bindings;
import dagon.graphics.shader;
import dagon.graphics.state;

class EnvironmentShader: Shader
{
    String vs, fs;

    this(Owner owner)
    {
        vs = Shader.load("data/__internal/shaders/Environment/Environment.vert.glsl");
        fs = Shader.load("data/__internal/shaders/Environment/Environment.frag.glsl");

        auto myProgram = New!ShaderProgram(vs, fs, this);
        super(myProgram, owner);
    }

    ~this()
    {
        vs.free();
        fs.free();
    }

    override void bindParameters(GraphicsState* state)
    {
        setParameter("viewMatrix", state.viewMatrix);
        setParameter("invViewMatrix", state.invViewMatrix);
        setParameter("projectionMatrix", state.projectionMatrix);
        setParameter("invProjectionMatrix", state.invProjectionMatrix);
        setParameter("resolution", state.resolution);
        setParameter("zNear", state.zNear);
        setParameter("zFar", state.zFar);

        // Texture 0 - color buffer
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, state.colorTexture);
        setParameter("colorBuffer", cast(int)0);

        // Texture 1 - depth buffer
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, state.depthTexture);
        setParameter("depthBuffer", cast(int)1);

        // Texture 2 - normal buffer
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, state.normalTexture);
        setParameter("normalBuffer", cast(int)2);

        // Texture 3 - pbr buffer
        glActiveTexture(GL_TEXTURE3);
        glBindTexture(GL_TEXTURE_2D, state.pbrTexture);
        setParameter("pbrBuffer", cast(int)3);

        // Textures 4, 5 - environment (equirectangular map, cube map)
        if (state.environment)
        {
            setParameter("fogColor", state.environment.fogColor);
            setParameter("fogStart", state.environment.fogStart);
            setParameter("fogEnd", state.environment.fogEnd);
            setParameter("ambientEnergy", state.environment.ambientEnergy);

            if (state.environment.ambientMap)
            {
                if (state.environment.ambientMap.isCubemap)
                {
                    glActiveTexture(GL_TEXTURE4);
                    glBindTexture(GL_TEXTURE_2D, 0);
                    setParameter("ambientTexture", cast(int)4);
                    
                    glActiveTexture(GL_TEXTURE5);
                    state.environment.ambientMap.bind();
                    setParameter("ambientTextureCube", cast(int)5);
                    
                    setParameterSubroutine("ambient", ShaderType.Fragment, "ambientCubemap");
                }
                else
                {
                    glActiveTexture(GL_TEXTURE4);
                    state.environment.ambientMap.bind();
                    setParameter("ambientTexture", cast(int)4);
                    
                    glActiveTexture(GL_TEXTURE5);
                    glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
                    setParameter("ambientTextureCube", cast(int)5);
                    
                    setParameterSubroutine("ambient", ShaderType.Fragment, "ambientEquirectangularMap");
                }
            }
            else
            {
                glActiveTexture(GL_TEXTURE4);
                glBindTexture(GL_TEXTURE_2D, 0);
                setParameter("ambientTexture", cast(int)4);
                
                glActiveTexture(GL_TEXTURE5);
                glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
                setParameter("ambientTextureCube", cast(int)5);
                
                setParameter("ambientVector", state.environment.ambientColor);
                
                setParameterSubroutine("ambient", ShaderType.Fragment, "ambientColor");
            }
        }
        else
        {
            setParameter("fogColor", Color4f(0.5f, 0.5f, 0.5f, 1.0f));
            setParameter("fogStart", 0.0f);
            setParameter("fogEnd", 1000.0f);
            setParameter("ambientEnergy", 1.0f);
            setParameter("ambientVector", Color4f(0.5f, 0.5f, 0.5f, 1.0f));
            
            glActiveTexture(GL_TEXTURE4);
            glBindTexture(GL_TEXTURE_2D, 0);
            setParameter("ambientTexture", cast(int)4);
            
            glActiveTexture(GL_TEXTURE5);
            glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
            setParameter("ambientTextureCube", cast(int)5);
            
            setParameterSubroutine("ambient", ShaderType.Fragment, "ambientColor");
        }

        // Texture 6 - occlusion buffer
        glActiveTexture(GL_TEXTURE6);
        if (glIsTexture(state.occlusionTexture))
        {
            glBindTexture(GL_TEXTURE_2D, state.occlusionTexture);
            setParameter("occlusionBuffer", cast(int)6);
            setParameter("haveOcclusionBuffer", true);
        }
        else
        {
            glBindTexture(GL_TEXTURE_2D, 0);
            setParameter("occlusionBuffer", cast(int)6);
            setParameter("haveOcclusionBuffer", false);
        }
        
        // Texture 7 - environment BRDF LUT
        glActiveTexture(GL_TEXTURE7);
        if (state.environment)
        {
            if (state.environment.ambientBRDF)
            {
                state.environment.ambientBRDF.bind();
                setParameter("ambientBRDF", cast(int)7);
                setParameter("haveAmbientBRDF", true);
            }
            else
            {
                glBindTexture(GL_TEXTURE_2D, 0);
                setParameter("ambientBRDF", cast(int)7);
                setParameter("haveAmbientBRDF", false);
            }
        }
        else
        {
            setParameter("haveAmbientBRDF", false);
        }
        
        glActiveTexture(GL_TEXTURE0);

        super.bindParameters(state);
    }

    override void unbindParameters(GraphicsState* state)
    {
        super.unbindParameters(state);

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE3);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE4);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE5);
        glBindTexture(GL_TEXTURE_CUBE_MAP, 0);

        glActiveTexture(GL_TEXTURE6);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE7);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE0);
    }
}
