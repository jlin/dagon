/*
Copyright (c) 2019-2024 Timur Gafarov

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

module dagon.ext.newton.character;

import std.math;
import dlib.core.ownership;
import dlib.core.memory;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import dlib.math.quaternion;
import dagon.core.event;
import dagon.core.time;
import dagon.graphics.entity;

import bindbc.newton;
import dagon.ext.newton.world;
import dagon.ext.newton.shape;
import dagon.ext.newton.rigidbody;

class NewtonCharacterComponent: EntityComponent, NewtonRaycaster
{
    NewtonPhysicsWorld world;
    NewtonSphereShape lowerShape;
    NewtonSphereShape upperShape;
    NewtonCompoundShape shape;
    NewtonRigidBody rbody;
    float height;
    float mass;
    bool onGround = false;
    Vector3f targetVelocity = Vector3f(0.0f, 0.0f, 0.0f);
    Matrix4x4f prevTransformation;
    float halfHeight;
    float shapeRadius;
    float eyeHeight;
    Vector3f sensorSize;
    bool groundContact = false;
    bool isJumping = false;
    bool isFalling = false;
    
    Vector3f groundPosition = Vector3f(0.0f, 0.0f, 0.0f);
    Vector3f groundContactPosition = Vector3f(0.0f, 0.0f, 0.0f);
    Vector3f groundNormal = Vector3f(0.0f, 1.0f, 0.0f);
    Vector3f groundContactNormal = Vector3f(0.0f, 0.0f, 0.0f);
    float maxRayDistance = 100.0f;
    protected float closestHit = 1.0f;
    
    this(NewtonPhysicsWorld world, Entity e, float height, float radius, float mass)
    {
        super(world.eventManager, e);
        this.world = world;
        this.height = height;
        this.mass = mass;
        this.halfHeight = height * 0.5f;
        shapeRadius = radius;
        eyeHeight = height * 0.5f;
        lowerShape = New!NewtonSphereShape(shapeRadius, world);
        lowerShape.setTransformation(translationMatrix(Vector3f(0.0f, -this.halfHeight + shapeRadius, 0.0f)));
        upperShape = New!NewtonSphereShape(shapeRadius, world);
        upperShape.setTransformation(translationMatrix(Vector3f(0.0f, shapeRadius, 0.0f)));
        NewtonCollisionShape[2] shapes = [lowerShape, upperShape];
        shape = New!NewtonCompoundShape(shapes, world);
        
        rbody = world.createDynamicBody(shape, mass);
        rbody.groupId = world.kinematicGroupId;
        rbody.raycastable = false;
        rbody.enableRotation = false;
        
        Quaternionf rot = e.rotation;
        rbody.transformation =
            translationMatrix(e.position) *
            rot.toMatrix4x4;
        NewtonBodySetMatrix(rbody.newtonBody, rbody.transformation.arrayof.ptr);
        prevTransformation = Matrix4x4f.identity;
        
        rbody.createUpVectorConstraint(Vector3f(0.0f, 1.0f, 0.0f));
        rbody.gravity = Vector3f(0.0f, -20.0f, 0.0f);
        NewtonBodySetAutoSleep(rbody.newtonBody, false);
        
        rbody.contactCallback = &onContact;
    }
    
    void onContact(NewtonRigidBody selfBody, NewtonRigidBody otherBody, const void* contact)
    {
        if (contact && !groundContact)
        {
            NewtonMaterial* mat = NewtonContactGetMaterial(contact);
            Vector3f contactPoint;
            Vector3f contactNormal;
            NewtonMaterialGetContactPositionAndNormal(mat, selfBody.newtonBody, contactPoint.arrayof.ptr, contactNormal.arrayof.ptr);
            
            float groundProj = dot(contactNormal, Vector3f(0.0f, 1.0f, 0.0f));
            if (groundProj > 0.2f)
            {
                groundContact = true;
                groundPosition = contactPoint;
                groundContactPosition = contactPoint;
                groundContactNormal = contactNormal;
            }
        }
    }
    
    float onRayHit(NewtonRigidBody nbody, Vector3f hitPoint, Vector3f hitNormal, float t)
    {
        if (t < closestHit)
        {
            groundPosition = hitPoint;
            groundNormal = hitNormal;
            closestHit = t;
            return t;
        }
        else
        {
            return 1.0f;
        }
    }
    
    bool raycast(Vector3f pstart, Vector3f pend)
    {
        closestHit = 1.0f;
        world.raycast(pstart, pend, this);
        groundPosition = pstart + (pend - pstart).normalized * maxRayDistance * closestHit;
        return (closestHit < 1.0f);
    }
    
    void updateVelocity()
    {
        Vector3f velocityChange = targetVelocity - rbody.velocity;
        velocityChange.y = 0.0f;
        rbody.velocity = rbody.velocity + velocityChange;
        
        targetVelocity = Vector3f(0.0f, 0.0f, 0.0f);
    }
    
    override void update(Time t)
    {
        rbody.update(t.delta);

        entity.prevTransformation = prevTransformation;

        entity.position = rbody.position.xyz;
        entity.transformation = rbody.transformation * scaleMatrix(entity.scaling);
        entity.invTransformation = entity.transformation.inverse;
        entity.rotation = rbody.rotation;

        entity.absoluteTransformation = entity.transformation;
        entity.invAbsoluteTransformation = entity.invTransformation;
        entity.prevAbsoluteTransformation = entity.prevTransformation;

        prevTransformation = entity.transformation;
        
        onGround = groundContact;
        groundContact = false;
        
        if (raycast(entity.position, entity.position + Vector3f(0.0f, -maxRayDistance, 0.0f)))
        {
            onGround = onGround || (entity.position.y - groundPosition.y) <= halfHeight;
        }
        
        if (!onGround)
        {
            float verticalSpeed = rbody.velocity.y;
            isJumping = verticalSpeed >  2.0f;
            isFalling = verticalSpeed < -2.0f;
        }
        else
        {
            isJumping = false;
            isFalling = false;
        }
    }
    
    void move(Vector3f direction, float speed)
    {
        targetVelocity += direction * speed;
    }
    
    void jump(float height)
    {
        if (onGround)
        {
            onGround = false;
            float jumpSpeed = sqrt(2.0f * height * -rbody.gravity.y);
            Vector3f v = rbody.velocity;
            v.y = jumpSpeed;
            rbody.velocity = v;
        }
    }
    
    Vector3f position()
    {
        return rbody.position.xyz;
    }
    
    Vector3f eyePoint()
    {
        return rbody.position.xyz + Vector3f(0.0f, eyeHeight, 0.0f);
    }
}

NewtonCharacterComponent makeCharacter(Entity entity, NewtonPhysicsWorld world, float height, float radius, float mass)
{
    return New!NewtonCharacterComponent(world, entity, height, radius, mass);
}
