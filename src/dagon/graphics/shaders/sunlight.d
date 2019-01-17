/*
Copyright (c) 2019 Timur Gafarov

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

module dagon.graphics.shaders.sunlight;

import std.stdio;
import std.math;

import dlib.core.memory;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.image.color;

import dagon.core.libs;
import dagon.core.ownership;
import dagon.graphics.rc;
import dagon.graphics.gbuffer;
import dagon.graphics.light;
import dagon.graphics.shadow;
import dagon.graphics.shader;
import dagon.graphics.framebuffer;
import dagon.graphics.cubemap;

class SunLightShader: Shader
{
    string vs = import("SunLight.vs");
    string fs = import("SunLight.fs");

    GBuffer gbuffer;
    LightSource light;
    CascadedShadowMap shadowMap;

    Matrix4x4f defaultShadowMatrix;

    this(GBuffer gbuffer, Owner o)
    {
        auto myProgram = New!ShaderProgram(vs, fs, this);
        super(myProgram, o);
        this.gbuffer = gbuffer;
        this.defaultShadowMatrix = Matrix4x4f.identity;
    }

    void bind(RenderingContext* rc2d, RenderingContext* rc3d)
    {
        setParameter("modelViewMatrix", rc2d.modelViewMatrix);
        setParameter("projectionMatrix", rc2d.projectionMatrix);

        setParameter("camProjectionMatrix", rc3d.projectionMatrix);
        setParameter("camViewMatrix", rc3d.viewMatrix);
        setParameter("camInvViewMatrix", rc3d.invViewMatrix);

        setParameter("viewSize", Vector2f(gbuffer.width, gbuffer.height));

        if (light)
        {
            setParameter("sunDirection", light.directionEye(rc3d.viewMatrix));
            Color4f col = Color4f(light.color.x, light.color.y, light.color.z, 1.0f);
            setParameter("sunColor", col);
            setParameter("sunEnergy", light.energy);
        }

        // Texture 0 - color buffer
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, gbuffer.colorTexture);
        setParameter("colorBuffer", 0);

        // Texture 1 - roughness-metallic-specularity buffer
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, gbuffer.rmsTexture);
        setParameter("rmsBuffer", 1);

        // Texture 2 - position buffer
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, gbuffer.positionTexture);
        setParameter("positionBuffer", 2);

        // Texture 3 - normal buffer
        glActiveTexture(GL_TEXTURE3);
        glBindTexture(GL_TEXTURE_2D, gbuffer.normalTexture);
        setParameter("normalBuffer", 3);

        // Texture 5 - emission buffer
        glActiveTexture(GL_TEXTURE5);
        glBindTexture(GL_TEXTURE_2D, gbuffer.emissionTexture);
        setParameter("emissionBuffer", 5);

        // Texture 6 - shadow map cascades (3 layer texture array)
        if (shadowMap)
        {
            glActiveTexture(GL_TEXTURE6);
            glBindTexture(GL_TEXTURE_2D_ARRAY, shadowMap.depthTexture);
            setParameter("shadowTextureArray", 6);
            setParameter("shadowTextureSize", cast(float)shadowMap.size);
            setParameter("shadowMatrix1", shadowMap.area1.shadowMatrix);
            setParameter("shadowMatrix2", shadowMap.area2.shadowMatrix);
            setParameter("shadowMatrix3", shadowMap.area3.shadowMatrix);

            setParameterSubroutine("shadowMap", ShaderType.Fragment, "shadowMapCascaded");
        }
        else
        {
            //setParameter("shadowMatrix1", defaultShadowMatrix);
            //setParameter("shadowMatrix2", defaultShadowMatrix);
            //setParameter("shadowMatrix3", defaultShadowMatrix);

            setParameterSubroutine("shadowMap", ShaderType.Fragment, "shadowMapNone");
        }

        glActiveTexture(GL_TEXTURE0);

        super.bind(rc2d);
    }

    void unbind(RenderingContext* rc2d, RenderingContext* rc3d)
    {
        super.unbind(rc2d);

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
        glBindTexture(GL_TEXTURE_CUBE_MAP, 0);

        glActiveTexture(GL_TEXTURE5);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE6);
        glBindTexture(GL_TEXTURE_2D_ARRAY, 0);

        glActiveTexture(GL_TEXTURE7);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE0);
    }
}
