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

module dagon.game.hudrenderer;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.image.color;

import dagon.core.bindings;
import dagon.core.event;
import dagon.core.time;
import dagon.graphics.entity;
import dagon.resource.scene;
import dagon.render.pipeline;
import dagon.render.stage;
import dagon.render.deferred;
import dagon.game.renderer;

class HUDStage: RenderStage
{
    this(RenderPipeline pipeline, EntityGroup group = null)
    {
        super(pipeline, group);
    }

    override void render()
    {
        if (view && group)
        {
            glScissor(view.x, view.y, view.width, view.height);
            glViewport(view.x, view.y, view.width, view.height);

            if (clear)
            {
                Color4f backgroundColor = Color4f(0.0f, 0.0f, 0.0f, 1.0f);
                if (state.environment)
                    backgroundColor = state.environment.backgroundColor;

                glClearColor(
                    backgroundColor.r,
                    backgroundColor.g,
                    backgroundColor.b,
                    backgroundColor.a);
                glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            }

            foreach(entity; group)
            if (entity.visible && entity.drawable)
            {
                state.layer = entity.layer;

                state.modelViewMatrix = state.viewMatrix * entity.absoluteTransformation;
                state.normalMatrix = state.modelViewMatrix.inverse.transposed;

                //TODO:

                if (entity.material)
                {
                    entity.material.bind(&state);
                    if (entity.material.shader)
                    {
                        state.shader = entity.material.shader;
                        entity.material.shader.bind();
                        entity.material.shader.bindParameters(&state);
                    }
                }

                entity.drawable.render(&state);

                if (entity.material)
                {
                    if (entity.material.shader)
                    {
                        entity.material.shader.unbindParameters(&state);
                        entity.material.shader.unbind();
                    }
                    entity.material.unbind(&state);
                }
            }
        }
    }
}

class HUDRenderer: Renderer
{
    RenderStage stageHUD;

    this(EventManager eventManager, Owner owner)
    {
        super(eventManager, owner);

        setViewport(0, 0, eventManager.windowWidth, eventManager.windowHeight);
        view.ortho = true;

        stageHUD = New!HUDStage(pipeline);
        stageHUD.clear = false;
        stageHUD.defaultMaterial.depthWrite = false;
        stageHUD.defaultMaterial.culling = false;
        stageHUD.view = view;
    }

    override void scene(Scene s)
    {
        stageHUD.group = s.foreground;
    }
}
