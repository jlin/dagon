/*
Copyright (c) 2019-2022 Timur Gafarov

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

module dagon.game.game;

import std.stdio;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.container.dict;

import dagon.core.bindings;
import dagon.core.event;
import dagon.core.time;
import dagon.core.application;
import dagon.core.config;
import dagon.graphics.state;
import dagon.graphics.entity;
import dagon.resource.scene;
import dagon.render.renderer;
import dagon.render.deferred;
import dagon.render.postprocrenderer;
import dagon.render.presentrenderer;
import dagon.render.hudrenderer;

version(Windows)
{
    pragma(lib, "user32");
    import core.sys.windows.windows;
}

class Game: Application
{
    Dict!(Scene, string) scenes;
    Scene currentScene;

    Renderer renderer;
    DeferredRenderer deferredRenderer;
    PostProcRenderer postProcessingRenderer;
    PresentRenderer presentRenderer;
    HUDRenderer hudRenderer;
    
    alias deferred = deferredRenderer;
    alias postProc = postProcessingRenderer;
    alias present = presentRenderer;
    alias hud = hudRenderer;
    
    Configuration config;
    
    bool dynamicViewport = true;
    
    // TODO: implement async engine instead
    Scene sceneForDeletion = null;

    this(uint w, uint h, bool fullscreen, string title, string[] args)
    {
        scenes = dict!(Scene, string);
        
        config = New!Configuration(this);
        if (config.fromFile("settings.conf"))
        {
            if ("windowWidth" in config.props)
                w = config.props["windowWidth"].toUInt;
            if ("windowHeight" in config.props)
                h = config.props["windowHeight"].toUInt;
            if ("fullscreen" in config.props)
                fullscreen = cast(bool)(config.props["fullscreen"].toUInt);
            if ("windowTitle" in config.props)
                title = config.props["windowTitle"].toString;
            version(Windows) if ("hideConsole" in config.props)
                if (config.props["hideConsole"].toUInt)
                    ShowWindow(GetConsoleWindow(), SW_HIDE);
        }
        else
        {
            writeln("Warning: no \"settings.conf\" found");
        }
        
        super(w, h, fullscreen, title, args);
        
        deferredRenderer = New!DeferredRenderer(eventManager, this);
        renderer = deferredRenderer;
        postProcessingRenderer = New!PostProcRenderer(eventManager, deferredRenderer.outputBuffer, deferredRenderer.gbuffer, this);
        presentRenderer = New!PresentRenderer(eventManager, postProcessingRenderer.outputBuffer, this);
        hudRenderer = New!HUDRenderer(eventManager, this);
        
        renderer.setViewport(0, 0, eventManager.windowWidth, eventManager.windowHeight);
        postProcessingRenderer.setViewport(0, 0, eventManager.windowWidth, eventManager.windowHeight);
        presentRenderer.setViewport(0, 0, eventManager.windowWidth, eventManager.windowHeight);
        hudRenderer.setViewport(0, 0, eventManager.windowWidth, eventManager.windowHeight);
        
        deferredRenderer.ssaoEnabled = false;
        postProcessingRenderer.motionBlurEnabled = false;
        postProcessingRenderer.glowEnabled = false;
        postProcessingRenderer.fxaaEnabled = false;
        postProcessingRenderer.lutEnabled = false;
        postProcessingRenderer.lensDistortionEnabled = false;
    }
    
    ~this()
    {
        Delete(scenes);
    }

    override void onUpdate(Time t)
    {
        if (sceneForDeletion)
        {
            deleteOwnedObject(sceneForDeletion);
            sceneForDeletion = null;
        }
        
        if (currentScene)
        {
            currentScene.update(t);
            
            renderer.scene = currentScene;
            renderer.update(t);
            
            postProcessingRenderer.activeCamera = renderer.activeCamera;
            postProcessingRenderer.update(t);
            
            presentRenderer.scene = currentScene;
            presentRenderer.update(t);
            
            hudRenderer.scene = currentScene;
            hudRenderer.update(t);
        }
    }

    override void onRender()
    {
        if (currentScene)
        {
            if (currentScene.canRender)
            {
                renderer.render();
                postProcessingRenderer.render();
                presentRenderer.inputBuffer = postProcessingRenderer.outputBuffer;
                presentRenderer.render();
                hudRenderer.render();
            }
        }
    }
    
    void resize(int width, int height)
    {
        if (renderer) renderer.setViewport(0, 0, width, height);
        if (postProcessingRenderer) postProcessingRenderer.setViewport(0, 0, width, height);
        if (presentRenderer) presentRenderer.setViewport(0, 0, width, height);
        if (hudRenderer) hudRenderer.setViewport(0, 0, width, height);
    }
    
    override void onResize(int width, int height)
    {
        if (dynamicViewport)
            resize(width, height);
    }
    
    GLuint frameTexture() @property
    {
        return presentRenderer.inputBuffer.colorTexture;
    }
    
    void setCurrentScene(Scene scene, bool releaseCurrent = false)
    {
        if (releaseCurrent && currentScene)
        {
            sceneForDeletion = currentScene;
        }
        
        currentScene = scene;
        currentScene.onResize(eventManager.windowWidth, eventManager.windowHeight);
        if (currentScene.loaded)
            currentScene.onReset();
    }
    
    void setCurrentScene(string name, bool releaseCurrent = false)
    {
        if (name in scenes)
            setCurrentScene(scenes[name], releaseCurrent);
    }
}
