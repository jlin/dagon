/*
Copyright (c) 2022-2024 Timur Gafarov

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

module dagon.render.passes.terrain;

import std.stdio;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.image.color;

import dagon.core.bindings;
import dagon.graphics.entity;
import dagon.graphics.terrain;
import dagon.graphics.screensurface;
import dagon.render.pipeline;
import dagon.render.pass;
import dagon.render.gbuffer;
import dagon.render.framebuffer;
import dagon.render.shaders.terrain;

class PassTerrain: RenderPass
{
    GBuffer gbuffer;
    ScreenSurface screenSurface;
    TerrainGeometryShader terrainShader;
    TerrainTextureLayerShader terrainTextureLayerShader;
    Framebuffer normalBuffer;
    Framebuffer texcoordBuffer;
    GLuint framebuffer = 0;
    
    this(RenderPipeline pipeline, GBuffer gbuffer, Framebuffer normalBuffer, Framebuffer texcoordBuffer, EntityGroup group = null)
    {
        super(pipeline, group);
        this.gbuffer = gbuffer;
        this.screenSurface = New!ScreenSurface(this);
        this.terrainShader = New!TerrainGeometryShader(this);
        this.terrainTextureLayerShader = New!TerrainTextureLayerShader(this);
        this.normalBuffer = normalBuffer;
        this.texcoordBuffer = texcoordBuffer;
    }
    
    void prepareFramebuffer()
    {
        if (framebuffer)
            return;
        
        glGenFramebuffers(1, &framebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, normalBuffer.colorTexture, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, texcoordBuffer.colorTexture, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT2, GL_TEXTURE_2D, gbuffer.velocityTexture, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT3, GL_TEXTURE_2D, gbuffer.emissionTexture, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_TEXTURE_2D, gbuffer.depthTexture, 0);
        
        GLenum[4] drawBuffers =
        [
            GL_COLOR_ATTACHMENT0, 
            GL_COLOR_ATTACHMENT1,
            GL_COLOR_ATTACHMENT2,
            GL_COLOR_ATTACHMENT3
        ];
        glDrawBuffers(drawBuffers.length, drawBuffers.ptr);
        
        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (status != GL_FRAMEBUFFER_COMPLETE)
            writeln(status);
        
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }
    
    void resize(uint w, uint h)
    {
        if (glIsFramebuffer(framebuffer))
        {
            glDeleteFramebuffers(1, &framebuffer);
            framebuffer = 0;
        }
    }
    
    override void render()
    {
        if (gbuffer is null || group is null)
            return;
        
        uint terrains = 0;
        
        prepareFramebuffer();
        
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, framebuffer);
        
        glScissor(0, 0, gbuffer.width, gbuffer.height);
        glViewport(0, 0, gbuffer.width, gbuffer.height);
        
        Color4f zero = Color4f(0, 0, 0, 0);
        glClearBufferfv(GL_COLOR, 0, zero.arrayof.ptr);
        glClearBufferfv(GL_COLOR, 1, zero.arrayof.ptr);
        
        state.depthMask = true;
        state.environment = pipeline.environment;
        
        terrainShader.bind();
        foreach(entity; group)
        {
            if (entity.visible && entity.drawable)
            {
                if (entityIsTerrain(entity))
                {
                    renderEntity(entity, terrainShader);
                    terrains++;
                }
            }
        }
        terrainShader.unbind();
        
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
        
        // Texturing passes
        // TODO: do it for each terrain entity (need to manage state properly)
        TerrainMaterial terrainMaterial = pipeline.environment.terrainMaterial;
        if (terrainMaterial && terrains > 0)
        {
            updateState();
            
            gbuffer.bind();
            
            state.normalTexture = normalBuffer.colorTexture;
            state.texcoordTexture = texcoordBuffer.colorTexture;
            state.depthMask = false;
            
            glScissor(0, 0, gbuffer.width, gbuffer.height);
            glViewport(0, 0, gbuffer.width, gbuffer.height);
            
            glEnablei(GL_BLEND, 0);
            glEnablei(GL_BLEND, 1);
            glEnablei(GL_BLEND, 2);
            glEnablei(GL_BLEND, 3);
            glBlendFuncSeparatei(0, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
            glBlendFuncSeparatei(1, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
            glBlendFuncSeparatei(2, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
            glBlendFuncSeparatei(3, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
            
            glDisable(GL_DEPTH_TEST);
            terrainTextureLayerShader.bind();
            
            if (terrainMaterial)
            {
                foreach(layer; terrainMaterial.layers)
                {
                    state.material = layer;
                    terrainTextureLayerShader.bindParameters(&state);
                    screenSurface.render(&state);
                    terrainTextureLayerShader.unbindParameters(&state);
                }
            }
            
            terrainTextureLayerShader.unbind();
            glEnable(GL_DEPTH_TEST);
            
            glDisablei(GL_BLEND, 0);
            glDisablei(GL_BLEND, 1);
            glDisablei(GL_BLEND, 2);
            glDisablei(GL_BLEND, 3);
            
            gbuffer.unbind();
        }
    }
}
