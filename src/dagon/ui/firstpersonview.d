/*
Copyright (c) 2017-2022 Timur Gafarov

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

module dagon.ui.firstpersonview;

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

class FirstPersonViewComponent: EntityComponent
{
    protected bool _active = true;
    protected bool _useRelativeMouseMode = true;
    
    bool mouseActive = true;
    
    float mouseSensitivity = 0.2f;
    float axisSensitivity = 20.0f;
    
    float pitchLimitMax = 60.0f;
    float pitchLimitMin = -60.0f;
    
    int prevMouseX = 0;
    int prevMouseY = 0;
    
    float pitch = 0.0f;
    float turn = 0.0f;
    
    Quaternionf orientationV = Quaternionf.identity;
    Quaternionf orientationH = Quaternionf.identity;
    
    Quaternionf baseOrientation = Quaternionf.identity;
    
    Vector3f direction = Vector3f(0.0f, 0.0f, 1.0f);
    Vector3f directionHorizontal = Vector3f(0.0f, 0.0f, 1.0f);
    Vector3f right = Vector3f(1.0f, 0.0f, 0.0f);
    Vector3f up = Vector3f(0.0f, 1.0f, 0.0f);
    
    this(EventManager em, Entity e)
    {
        super(em, e);
        active = true;
        useRelativeMouseMode = true;
        reset();
    }
    
    void active(bool mode) @property
    {
        _active = mode;
        prevMouseX = eventManager.mouseX;
        prevMouseY = eventManager.mouseY;
        eventManager.setRelativeMouseMode(_useRelativeMouseMode && _active);
        if (!_active)
        {
            eventManager.setMouseToCenter();
        }
    }
    
    bool active() @property
    {
        return _active;
    }
    
    void useRelativeMouseMode(bool mode) @property
    {
        _useRelativeMouseMode = mode;
        eventManager.setRelativeMouseMode(_useRelativeMouseMode && _active);
    }
    
    bool useRelativeMouseMode() @property
    {
        return _useRelativeMouseMode;
    }
    
    void reset()
    {
        pitch = 0.0f;
        turn = 0.0f;
        if (!useRelativeMouseMode)
            eventManager.setMouseToCenter();
        prevMouseX = eventManager.mouseX;
        prevMouseY = eventManager.mouseY;
    }
    
    override void update(Time time)
    {
        processEvents();
        
        if (_active & mouseActive)
        {
            float mouseRelH, mouseRelV;
            if (useRelativeMouseMode)
            {
                mouseRelH = eventManager.mouseRelX * mouseSensitivity;
                mouseRelV = eventManager.mouseRelY * mouseSensitivity;
            }
            else
            {
                mouseRelH =  (eventManager.mouseX - prevMouseX) * mouseSensitivity;
                mouseRelV = (eventManager.mouseY - prevMouseY) * mouseSensitivity;
            }
            
            float axisV = inputManager.getAxis("vertical") * axisSensitivity * mouseSensitivity;
            float axisH = inputManager.getAxis("horizontal") * axisSensitivity * mouseSensitivity;
            
            pitch -= mouseRelV + axisV;
            turn -= mouseRelH + axisH;
            
            if (pitch > pitchLimitMax)
            {
                pitch = pitchLimitMax;
            }
            else if (pitch < pitchLimitMin)
            {
                pitch = pitchLimitMin;
            }
            
            if (!useRelativeMouseMode)
                eventManager.setMouseToCenter();
            
            prevMouseX = eventManager.mouseX;
            prevMouseY = eventManager.mouseY;
        }
        
        orientationV = rotationQuaternion(Vector3f(1.0f, 0.0f, 0.0f), degtorad(pitch));
        orientationH = rotationQuaternion(Vector3f(0.0f, 1.0f, 0.0f), degtorad(turn));
        
        Quaternionf orientation = baseOrientation * orientationH * orientationV;
        
        entity.transformation =
            (translationMatrix(entity.position) *
            orientation.toMatrix4x4 *
            scaleMatrix(entity.scaling));
        
        entity.invTransformation = entity.transformation.inverse;
        
        if (entity.parent)
        {
            entity.absoluteTransformation = entity.parent.absoluteTransformation * entity.transformation;
            entity.invAbsoluteTransformation = entity.invTransformation * entity.parent.invAbsoluteTransformation;
            entity.prevAbsoluteTransformation = entity.parent.prevAbsoluteTransformation * entity.prevTransformation;
        }
        else
        {
            entity.absoluteTransformation = entity.transformation;
            entity.invAbsoluteTransformation = entity.invTransformation;
            entity.prevAbsoluteTransformation = entity.prevTransformation;
        }
        
        direction = orientation.rotate(Vector3f(0.0f, 0.0f, 1.0f));
        directionHorizontal = orientationH.rotate(Vector3f(0.0f, 0.0f, 1.0f));
        right = orientationH.rotate(Vector3f(1.0f, 0.0f, 0.0f));
        up = orientationH.rotate(Vector3f(01.0f, 1.0f, 0.0f));
    }
    
    override void onFocusGain()
    {
        mouseActive = true;
    }
    
    override void onFocusLoss()
    {
        mouseActive = false;
    }
    
    void moveForward(float speed)
    {
        Vector3f forward = entity.transformation.forward;
        entity.position -= forward.normalized * speed;
    }
    
    void moveBack(float speed)
    {
        Vector3f forward = entity.transformation.forward;
        entity.position += forward.normalized * speed;
    }
    
    void strafeRight(float speed)
    {
        Vector3f right = entity.transformation.right;
        entity.position += right.normalized * speed;
    }
    
    void strafeLeft(float speed)
    {
        Vector3f right = entity.transformation.right;
        entity.position -= right.normalized * speed;
    }
}
