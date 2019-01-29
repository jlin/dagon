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

module dagon.logics.tween;

import dlib.math.vector;
import dlib.math.quaternion;
import dlib.math.easing;
import dlib.math.interpolation;
import dlib.image.color;
import dagon.logics.entity;

enum TweenDataType
{
    Float,
    Vector,
    Quaternion,
    Color
}

enum TweenType
{
    Unknown = 0,
    Position,
    Rotation,
    Scaling,
    Color,
    Alpha,
}

enum Easing
{
    Linear,
    QuadIn,
    QuadOut,
    QuadInOut,
    BackIn,
    BackOut,
    BackInOut,
    BounceOut
}

struct Tween
{
    TweenDataType dataType;
    TweenType type = TweenType.Unknown;
    Easing easing;
    bool active = false;
    Entity entity;
    double duration;
    double time = 0.0f;
    bool loop = false;

    union
    {
        Quaternionf fromQuaternion;
        Color4f fromColor;
        Vector3f fromVector;
        float fromFloat;
    }

    union
    {
        Quaternionf toQuaternion;
        Color4f toColor;
        Vector3f toVector;
        float toFloat;
    }

    this(Entity entity, TweenType type, Quaternionf start, Quaternionf end, double duration, Easing easing = Easing.Linear)
    {
        this.dataType = TweenDataType.Quaternion;
        this.type = type;
        this.easing = easing;
        this.active = true;
        this.entity = entity;
        this.duration = duration;
        this.time = 0.0f;
        this.fromQuaternion = start;
        this.toQuaternion = end;
    }

    this(Entity entity, TweenType type, Vector3f start, Vector3f end, double duration, Easing easing = Easing.Linear)
    {
        this.dataType = TweenDataType.Vector;
        this.type = type;
        this.easing = easing;
        this.active = true;
        this.entity = entity;
        this.duration = duration;
        this.time = 0.0f;
        this.fromVector = start;
        this.toVector = end;
    }

    this(Entity entity, TweenType type, Color4f start, Color4f end, double duration, Easing easing = Easing.Linear)
    {
        this.dataType = TweenDataType.Color;
        this.type = type;
        this.easing = easing;
        this.active = true;
        this.entity = entity;
        this.duration = duration;
        this.time = 0.0f;
        this.fromColor = start;
        this.toColor = end;
    }

    this(Entity entity, TweenType type, float start, float end, double duration, Easing easing = Easing.Linear)
    {
        this.dataType = TweenDataType.Float;
        this.type = type;
        this.easing = easing;
        this.active = true;
        this.entity = entity;
        this.duration = duration;
        this.time = 0.0f;
        this.fromFloat = start;
        this.toFloat = end;
    }

    void update(double dt)
    {
        if (active && entity)
        {
            time += dt;
            float t;
            if (time > duration)
            {
                time = 0.0;
                t = 0.0f;
                if (!loop)
                    active = false;
            }
            else
            {
                t = time / duration;
            }

            applyTween(t);
        }
    }

    void applyTween(float t)
    {
        if (type == TweenType.Position)
            entity.position = lerp(fromVector, toVector, ease(t));
        else if (type == TweenType.Rotation)
            entity.rotation = slerp(fromQuaternion, toQuaternion, ease(t));
        else if (type == TweenType.Scaling)
            entity.scaling = lerp(fromVector, toVector, ease(t));
    }

    float ease(float t)
    {
        if (easing == Easing.Linear) return t;
        else if (easing == Easing.QuadIn) return easeInQuad(t);
        else if (easing == Easing.QuadOut) return easeOutQuad(t);
        else if (easing == Easing.QuadInOut) return easeInOutQuad(t);
        else if (easing == Easing.BackIn) return easeInBack(t);
        else if (easing == Easing.BackOut) return easeOutBack(t);
        else if (easing == Easing.BackInOut) return easeInOutBack(t);
        else if (easing == Easing.BounceOut) return easeOutBounce(t);
        else return t;
    }
}
