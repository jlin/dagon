/*
Copyright (c) 2011-2025 Timur Gafarov 

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
module dagon.kinematics.bvh;

import std.array;
import std.math;

import dlib.core.memory;
import dlib.core.compound;
import dlib.container.array;
import dlib.math.utils;
import dlib.math.vector;
import dlib.geometry.aabb;
import dlib.geometry.sphere;
import dlib.geometry.ray;

/*
 * Bounding Volume Hierarchy implementation
 */

// Returns the axis that has the largest length
Axis boxGetMainAxis(AABB box)
{
    float xl = box.size.x;
    float yl = box.size.y;
    float zl = box.size.z;
         
    if (xl < yl)
    {
        if (yl < zl)
           return Axis.z;
        return Axis.y;
    }
    else if (xl < zl)
        return Axis.z;
    return Axis.x;
}

struct SplitPlane
{
    public:
    float split;
    Axis axis;
    
    this(float s, Axis ax)
    {
        split = s;
        axis = ax;
    }
}

SplitPlane boxGetSplitPlaneForAxis(AABB box, Axis a)
{
    return SplitPlane(box.center[a], a);
}

Compound!(AABB, AABB) boxSplitWithPlane(AABB box, SplitPlane sp)
{
    Vector3f minLP = box.pmin;
    Vector3f maxLP = box.pmax;
    maxLP[sp.axis] = sp.split;
    
    Vector3f minRP = box.pmin;
    Vector3f maxRP = box.pmax;
    minRP[sp.axis] = sp.split;

    AABB leftB = boxFromMinMaxPoints(minLP, maxLP);
    AABB rightB = boxFromMinMaxPoints(minRP, maxRP);

    return compound(leftB, rightB);
}

AABB enclosingAABB(T)(T[] objects)
{
    Vector3f pmin = objects[0].boundingBox.pmin;
    Vector3f pmax = pmin;
    
    void adjustMinPoint(Vector3f p)
    {    
        if (p.x < pmin.x) pmin.x = p.x;
        if (p.y < pmin.y) pmin.y = p.y;
        if (p.z < pmin.z) pmin.z = p.z;
    }
    
    void adjustMaxPoint(Vector3f p)
    {
        if (p.x > pmax.x) pmax.x = p.x;
        if (p.y > pmax.y) pmax.y = p.y;
        if (p.z > pmax.z) pmax.z = p.z;
    }

    foreach(ref obj; objects)
    {
        adjustMinPoint(obj.boundingBox.pmin);
        adjustMaxPoint(obj.boundingBox.pmax);
    }
    
    return boxFromMinMaxPoints(pmin, pmax);
}

class BVHNode(T)
{
    Array!T objects;
    AABB aabb;
    BVHNode[2] child;
    uint userData;

    this(Array!T objs)
    {
        objects = objs;
        aabb = enclosingAABB(objects.data);
    }
    
    void free()
    {
        objects.free();
        if (child[0] !is null) child[0].free();
        if (child[1] !is null) child[1].free();
        Delete(this);
    }
    
    SphereTraverseAggregate!T traverseBySphere(Sphere* sphere)
    {
        return SphereTraverseAggregate!(T)(this, sphere);
    }
    
    RayTraverseAggregate!T traverseByRay(Ray* ray)
    {
        return RayTraverseAggregate!(T)(this, ray);
    }
}

struct SphereTraverseAggregate(T)
{
    BVHNode!T node;
    Sphere* sphere;
    
    int opApply(int delegate(ref T) dg)
    {
        int result = 0;
        
        Vector3f cn;
        float pd;
        if (node.aabb.intersectsSphere(*sphere, cn, pd))
        {
            if (node.child[0] !is null)
            {
                result = node.child[0].traverseBySphere(sphere).opApply(dg);
                if (result)
                    return result;
            }
            
            if (node.child[1] !is null)
            {
                result = node.child[1].traverseBySphere(sphere).opApply(dg);
                if (result)
                    return result;
            }
            
            foreach(ref obj; node.objects.data)
                dg(obj);
        }
        else
            return result;
            
        return result;
    }
}

struct RayTraverseAggregate(T)
{
    BVHNode!T node;
    Ray* ray;
    
    int opApply(int delegate(ref T) dg) // TODO: nearest intersection point
    {
        int result = 0;
        
        float it = 0.0f;
        if (node.aabb.intersectsSegment(ray.p0, ray.p1, it))
        { 
            if (node.child[0] !is null)
            {
                result = node.child[0].traverseByRay(ray).opApply(dg);
                if (result)
                    return result;
            }
            
            if (node.child[1] !is null)
            {
                result = node.child[1].traverseByRay(ray).opApply(dg);
                if (result)
                    return result;
            }
            
            foreach(ref obj; node.objects.data)
                dg(obj);
        }
        else
            return result;
            
        return result;
    }
}

/+
void traverseBySphere(T)(BVHNode!T node, ref Sphere sphere /*, void delegate(ref T) func*/)
{
    Vector3f cn;
    float pd;
    if (node.aabb.intersectsSphere(sphere, cn, pd))
    {
        //if (node.child[0] !is null)
        //    node.child[0].traverseBySphere(sphere, func);
        //if (node.child[1] !is null)
        //    node.child[1].traverseBySphere(sphere, func);

        //foreach(ref obj; node.objects.data)
        //    func(obj);
    }
}
+/
/*
void traverse(T)(BVHNode!T node, void delegate(BVHNode!T) func)
{
    if (node.child[0] !is null)
        node.child[0].traverse(func);
    if (node.child[1] !is null)
        node.child[1].traverse(func);

    func(node);
}
*/
/*
void traverseByRay(T)(BVHNode!T node, Ray ray, void delegate(ref T) func)
{
    float it = 0.0f;
    if (node.aabb.intersectsSegment(ray.p0, ray.p1, it))
    {
        if (node.child[0] !is null)
            node.child[0].traverseByRay(ray, func);
        if (node.child[1] !is null)
            node.child[1].traverseByRay(ray, func);

        foreach(ref obj; node.objects.data)
            func(obj);
    }
}
*/

// TODO:
// - support multithreading (2 children = 2 threads)
// - add ESC (Early Split Clipping)
enum Heuristic
{
    HMA, // Half Main Axis
    SAH, // Surface Area Heuristic
    //ESC  // Early Split Clipping
}

DynamicArray!T duplicate(T)(DynamicArray!T arr)
{
    DynamicArray!T res;
    foreach(v; arr.data)
        res.append(v);
    return res;
}

class BVHTree(T)
{
    BVHNode!T root;

    this(DynamicArray!T objects, 
         uint maxObjectsPerNode = 8,
         uint maxRecursionDepth = 10,
         Heuristic splitHeuristic = Heuristic.SAH)
    {
        root = construct(objects, 0, maxObjectsPerNode, maxRecursionDepth, splitHeuristic);
    }
    
    void free()
    {
        root.free();
        Delete(this);
    }
    
    import std.stdio;

    BVHNode!T construct(
         DynamicArray!T objects, 
         uint rec,
         uint maxObjectsPerNode,
         uint maxRecursionDepth,
         Heuristic splitHeuristic)
    {
        BVHNode!T node = New!(BVHNode!T)(duplicate(objects));

        if (node.objects.data.length <= maxObjectsPerNode)
        {
            return node;
        }
        
        if (rec == maxRecursionDepth)
        {
            return node;
        }
        
        AABB box = enclosingAABB(node.objects.data);

        SplitPlane sp;
        if (splitHeuristic == Heuristic.HMA)
            sp = getHalfMainAxisSplitPlane(node.objects.data, box);
        else if (splitHeuristic == Heuristic.SAH)
            sp = getSAHSplitPlane(node.objects.data, box);
        else
            assert(0, "BVH: unsupported split heuristic");

        auto boxes = boxSplitWithPlane(box, sp);

        DynamicArray!T leftObjects;
        DynamicArray!T rightObjects;
        
        foreach(obj; node.objects.data)
        {
            if (boxes[0].intersectsAABB(obj.boundingBox))
                leftObjects.append(obj);
            else if (boxes[1].intersectsAABB(obj.boundingBox))
                rightObjects.append(obj);
        }

        if (leftObjects.data.length > 0 || rightObjects.data.length > 0)
            node.objects.free();

        if (leftObjects.data.length > 0)
            node.child[0] = construct(leftObjects, rec + 1, maxObjectsPerNode, maxRecursionDepth, splitHeuristic);
        else
            node.child[0] = null;

        if (rightObjects.data.length > 0)
            node.child[1] = construct(rightObjects, rec + 1, maxObjectsPerNode, maxRecursionDepth, splitHeuristic);
        else
            node.child[1] = null;

        leftObjects.free();
        rightObjects.free();

        return node;
    }

    SplitPlane getHalfMainAxisSplitPlane(T[] objects, ref AABB box)
    {
        Axis axis = boxGetMainAxis(box);
        return boxGetSplitPlaneForAxis(box, axis);
    }

    SplitPlane getSAHSplitPlane(T[] objects, ref AABB box)
    {
        Axis axis = boxGetMainAxis(box);
        
        float minAlongSplitPlane = box.pmin[axis];
        float maxAlongSplitPlane = box.pmax[axis];
        
        float bestSAHCost = float.nan;
        float bestSplitPoint = float.nan;

        int iterations = 12;
        foreach (i; 0..iterations)
        {
            float valueOfSplit = minAlongSplitPlane + 
                               ((maxAlongSplitPlane - minAlongSplitPlane) / (iterations + 1.0f) * (i + 1.0f));

            SplitPlane SAHSplitPlane = SplitPlane(valueOfSplit, axis);
            auto boxes = boxSplitWithPlane(box, SAHSplitPlane);

            uint leftObjectsLength = 0;
            uint rightObjectsLength = 0;

            foreach(obj; objects)
            {
                if (boxes[0].intersectsAABB(obj.boundingBox))
                    leftObjectsLength++;
                else if (boxes[1].intersectsAABB(obj.boundingBox))
                    rightObjectsLength++;
            }

            if (leftObjectsLength > 0 && rightObjectsLength > 0)
            {
                float SAHCost = getSAHCost(boxes[0], leftObjectsLength, 
                                           boxes[1], rightObjectsLength, box);

                if (bestSAHCost.isNaN || SAHCost < bestSAHCost)
                {
                    bestSAHCost = SAHCost;
                    bestSplitPoint = valueOfSplit;
                }
            }
        }
        
        return SplitPlane(bestSplitPoint, axis);
    }

    float getSAHCost(AABB leftBox, uint numLeftObjects, 
                     AABB rightBox, uint numRightObjects,
                     AABB parentBox)
    {
        return getSurfaceArea(leftBox) / getSurfaceArea(parentBox) * numLeftObjects
             + getSurfaceArea(rightBox) / getSurfaceArea(parentBox) * numRightObjects;
    }

    float getSurfaceArea(AABB bbox)
    {
        float width = bbox.pmax.x - bbox.pmin.x;
        float height = bbox.pmax.y - bbox.pmin.y;
        float depth = bbox.pmax.z - bbox.pmin.z;
        return 2.0f * (width * height + width * depth + height * depth);
    }
}

