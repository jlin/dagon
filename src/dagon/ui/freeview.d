/*
Copyright (c) 2017-2025 Timur Gafarov

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

module dagon.ui.freeview;

import std.math;

import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.quaternion;
import dlib.math.transformation;
import dlib.math.utils;

import dagon.core.event;
import dagon.core.keycodes;
import dagon.core.time;
import dagon.graphics.entity;

class FreeviewComponent: EntityComponent
{
    int prevMouseX;
    int prevMouseY;
    float mouseTranslationSensibility;
    float mouseRotationSensibility;
    float mouseZoomSensibility;
    
    Vector3f target;
    Vector3f smoothTarget;
    
    float distanceToTagret;
    float smoothDistanceToTagret;
    
    Vector3f rotation;
    Vector3f smoothRotation;
    
    float translationStiffness;
    float rotationStiffness;
    float zoomStiffness;
    
    Quaternionf orientation;
    Matrix4x4f transform;
    Matrix4x4f invTransform;
    
    bool active;
    
    bool enableMouseTranslation;
    bool enableMouseRotation;
    bool enableMouseZoom;
    
    this(EventManager em, Entity e)
    {
        super(em, e);
        reset();
    }
    
    void reset()
    {
        prevMouseX = eventManager.mouseX;
        prevMouseY = eventManager.mouseY;
        
        mouseTranslationSensibility = 0.1f;
        mouseRotationSensibility = 1.0f;
        mouseZoomSensibility = 0.2f;
        
        target = Vector3f(0.0f, 0.0f, 0.0f);
        smoothTarget = Vector3f(0.0f, 0.0f, 0.0f);
        
        distanceToTagret = 20.0f;
        smoothDistanceToTagret = 20.0f;
        
        rotation = Vector3f(45.0f, 45.0f, 0.0f);
        smoothRotation = rotation;
        
        translationStiffness = 1.0f;
        rotationStiffness = 1.0f;
        zoomStiffness = 1.0f;
        
        orientation = Quaternionf.identity;
        transform = Matrix4x4f.identity;
        invTransform = Matrix4x4f.identity;
        
        active = true;
        
        enableMouseTranslation = true;
        enableMouseRotation = true;
        enableMouseZoom = true;
        
        transformEntity();
    }
    
    override void update(Time time)
    {
        processEvents();
        
        if (active)
        {
            if (eventManager.mouseButtonPressed[MB_RIGHT] && enableMouseTranslation)
            {
                float shiftx = (eventManager.mouseX - prevMouseX) * mouseTranslationSensibility;
                float shifty = -(eventManager.mouseY - prevMouseY) * mouseTranslationSensibility;
                Vector3f trans = up * shifty + right * shiftx;
                target += trans;
            }
            else if (eventManager.mouseButtonPressed[MB_LEFT] && eventManager.keyPressed[KEY_LCTRL] && enableMouseZoom)
            {
                float shiftx = (eventManager.mouseX - prevMouseX) * mouseZoomSensibility;
                float shifty = (eventManager.mouseY - prevMouseY) * mouseZoomSensibility;
                zoom(shiftx + shifty);
            }
            else if (eventManager.mouseButtonPressed[MB_LEFT] && enableMouseRotation)
            {
                float turn = (eventManager.mouseX - prevMouseX) * mouseRotationSensibility;
                float pitch = (eventManager.mouseY - prevMouseY) * mouseRotationSensibility;
                
                rotation.x += pitch;
                rotation.y += turn;
            }
            
            prevMouseX = eventManager.mouseX;
            prevMouseY = eventManager.mouseY;
        }
        
        smoothTarget += (target - smoothTarget) * translationStiffness;
        smoothDistanceToTagret += (distanceToTagret - smoothDistanceToTagret) * zoomStiffness;
        smoothRotation += (rotation - smoothRotation) * rotationStiffness;
        
        transformEntity();
    }
    
    void transformEntity()
    {
        Quaternionf qPitch = rotationQuaternion(Vector3f(1.0f, 0.0f, 0.0f), degtorad(smoothRotation.x));
        Quaternionf qTurn = rotationQuaternion(Vector3f(0.0f, 1.0f, 0.0f), degtorad(smoothRotation.y));
        Quaternionf qRoll = rotationQuaternion(Vector3f(0.0f, 0.0f, 1.0f), degtorad(smoothRotation.z));
        
        orientation = qPitch * qTurn * qRoll;
        Matrix4x4f orientationMatrix = orientation.toMatrix4x4();
        invTransform =
            translationMatrix(Vector3f(0.0f, 0.0f, -smoothDistanceToTagret)) *
            orientationMatrix *
            translationMatrix(smoothTarget);
        
        transform = invTransform.inverse;
        
        entity.prevTransformation = entity.transformation;
        entity.transformation = transform;
        entity.invTransformation = invTransform;
        
        entity.absoluteTransformation = entity.transformation;
        entity.invAbsoluteTransformation = entity.invTransformation;
        entity.prevAbsoluteTransformation = entity.prevTransformation;
    }
    
    void setRotation(float p, float t, float r)
    {
        rotation = Vector3f(p, t, r);
        smoothRotation = rotation;
    }
    
    // 2:1 isometry
    void setIsometricRotation()
    {
        setRotation(30.0f, 45.0f, 0.0f);
    }
    
    void setRotationSmooth(float p, float t, float r)
    {
        rotation = Vector3f(p, t, r);
    }
    
    void rotate(float p, float t, float r)
    {
        rotation += Vector3f(p, t, r);
    }
    
    void setTarget(Vector3f pos)
    {
        target = pos;
        smoothTarget = target;
    }
    
    void setTargetSmooth(Vector3f pos)
    {
        target = pos;
    }
    
    void setTarget(Entity e)
    {
        target = e.positionAbsolute;
        smoothTarget = target;
    }
    
    void setTargetSmooth(Entity e)
    {
        target = e.positionAbsolute;
    }

    void translateTarget(Vector3f pos)
    {
        target += pos;
    }
    
    void setZoom(float z)
    {
        distanceToTagret = z;
        smoothDistanceToTagret = z;
    }

    void setZoomSmooth(float z)
    {
        distanceToTagret = z;
    }

    void zoom(float z)
    {
        distanceToTagret -= z;
    }

    Vector3f position()
    {
        return transform.translation();
    }

    Vector3f direction()
    {
        return transform.forward();
    }

    Vector3f right()
    {
        return transform.right();
    }

    Vector3f up()
    {
        return transform.up();
    }

    void screenToWorld(
        int scrx,
        int scry,
        int scrw,
        int scrh,
        float yfov,
        ref float worldx,
        ref float worldy,
        bool snap)
    {
        Vector3f camPos = position();
        Vector3f camDir = direction();

        float aspect = cast(float)scrw / cast(float)scrh;

        float xfov = fovXfromY(yfov, aspect);

        float tfov1 = tan(yfov*PI/360.0f);
        float tfov2 = tan(xfov*PI/360.0f);

        Vector3f camUp = up() * tfov1;
        Vector3f camRight = right() * tfov2;

        float width  = 1.0f - 2.0f * cast(float)(scrx) / cast(float)(scrw);
        float height = 1.0f - 2.0f * cast(float)(scry) / cast(float)(scrh);

        float mx = camDir.x + camUp.x * height + camRight.x * width;
        float my = camDir.y + camUp.y * height + camRight.y * width;
        float mz = camDir.z + camUp.z * height + camRight.z * width;

        worldx = snap? floor(camPos.x - mx * camPos.y / my) : (camPos.x - mx * camPos.y / my);
        worldy = snap? floor(camPos.z - mz * camPos.y / my) : (camPos.z - mz * camPos.y / my);
    }
    
    override void onMouseButtonDown(int button)
    {
        if (!active)
            return;
        
        if (button == MB_LEFT)
        {
            prevMouseX = eventManager.mouseX;
            prevMouseY = eventManager.mouseY;
        }
    }
    
    override void onMouseWheel(int x, int y)
    {
        if (!active || !enableMouseZoom)
            return;
        
        zoom(cast(float)y * mouseZoomSensibility);
    }
}
