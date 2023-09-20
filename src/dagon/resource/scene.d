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

module dagon.resource.scene;

import std.path;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.math.vector;

import dagon.core.application;
import dagon.core.bindings;
import dagon.core.event;
import dagon.core.time;

import dagon.graphics.entity;
import dagon.graphics.camera;
import dagon.graphics.light;
import dagon.graphics.environment;
import dagon.graphics.shapes;
import dagon.graphics.material;
import dagon.graphics.world;

import dagon.resource.asset;
import dagon.resource.obj;
import dagon.resource.gltf;
import dagon.resource.image;
import dagon.resource.texture;
import dagon.resource.text;
import dagon.resource.binary;

class Scene: EventListener
{
    Application application;
    AssetManager assetManager;
    World world;
    /*
    EntityGroupSpatial spatial;
    EntityGroupSpatialOpaque spatialOpaqueStatic;
    EntityGroupSpatialOpaque spatialOpaqueDynamic;
    EntityGroupSpatialTransparent spatialTransparent;
    EntityGroupBackground background;
    EntityGroupForeground foreground;
    EntityGroupLights lights;
    EntityGroupSunLights sunLights;
    EntityGroupAreaLights areaLights;
    EntityGroupDecals decals;
    */
    Environment environment;
    ShapeBox decalShape;
    bool isLoading = false;
    bool loaded = false;
    bool canRender = false;
    bool focused = true;

    this(Application application)
    {
        super(application.eventManager, application);
        this.application = application;
        world = New!World(this);
        /*
        spatial = New!EntityGroupSpatial(world, this);
        spatialOpaqueStatic = New!EntityGroupSpatialOpaque(world, false, this);
        spatialOpaqueDynamic = New!EntityGroupSpatialOpaque(world, true, this);
        spatialTransparent = New!EntityGroupSpatialTransparent(world, this);
        background = New!EntityGroupBackground(world, this);
        foreground = New!EntityGroupForeground(world, this);
        lights = New!EntityGroupLights(world, this);
        sunLights = New!EntityGroupSunLights(world, this);
        areaLights = New!EntityGroupAreaLights(world, this);
        decals = New!EntityGroupDecals(world, this);
        */

        environment = New!Environment(this);
        decalShape = New!ShapeBox(Vector3f(1, 1, 1), this);

        assetManager = New!AssetManager(eventManager, this);
        beforeLoad();
        isLoading = true;
        assetManager.loadThreadSafePart();
    }

    // Set preload to true if you want to load the asset immediately
    // before actual loading (e.g., to render a loading screen)
    Asset addAsset(Asset asset, string filename, bool preload = false)
    {
        if (preload)
            assetManager.preloadAsset(asset, filename);
        else
            assetManager.addAsset(asset, filename);
        return asset;
    }

    T addAssetAs(T)(string filename, bool preload = false)
    {
        T newAsset;
        if (assetManager.assetExists(filename))
            newAsset = cast(T)assetManager.getAsset(filename);
        else
        {
            static if (is(T: ImageAsset) || is(T: TextureAsset))
            {
                newAsset = New!T(assetManager);
            }
            /*
            else static if (is(T: PackageAsset))
            {
                newAsset = New!T(this, assetManager);
            }
            */
            else
            {
                newAsset = New!T(assetManager);
            }
            addAsset(newAsset, filename, preload);
        }
        return newAsset;
    }

    alias addImageAsset = addAssetAs!ImageAsset;
    alias addTextureAsset = addAssetAs!TextureAsset;
    alias addOBJAsset = addAssetAs!OBJAsset;
    alias addGLTFAsset = addAssetAs!GLTFAsset;
    alias addTextAsset = addAssetAs!TextAsset;
    alias addBinaryAsset = addAssetAs!BinaryAsset;
    //alias addPackageAsset = addAssetAs!PackageAsset;

    Material addMaterial()
    {
        return New!Material(assetManager);
    }

    Material addDecalMaterial()
    {
        auto mat = addMaterial();
        mat.blendMode = Transparent;
        mat.depthWrite = false;
        mat.useCulling = false;
        return mat;
    }

    /*
    Cubemap addCubemap(uint size)
    {
        return New!Cubemap(size, assetManager);
    }
    */

    Entity addEntity(Entity parent = null)
    {
        Entity e = New!Entity(world);
        if (parent)
            e.setParent(parent);
        return e;
    }

    Entity useEntity(Entity e)
    {
        world.addEntity(e);
        return e;
    }

    Entity addEntityHUD(Entity parent = null)
    {
        Entity e = New!Entity(world);
        e.layer = EntityLayer.Foreground;
        if (parent)
            e.setParent(parent);
        return e;
    }

    Camera addCamera(Entity parent = null)
    {
        Camera c = New!Camera(world);
        if (parent)
            c.setParent(parent);
        return c;
    }

    Light addLight(LightType type, Entity parent = null)
    {
        Light light = New!Light(world);
        if (parent)
            light.setParent(parent);
        light.type = type;
        return light;
    }

    Entity addDecal(Entity parent = null)
    {
        Entity e = New!Entity(world);
        e.decal = true;
        e.drawable = decalShape;
        if (parent)
            e.setParent(parent);
        return e;
    }

    // Override me
    void beforeLoad()
    {
    }

    // Override me
    void onLoad(Time t, float progress)
    {
    }

    // Override me
    void afterLoad()
    {
    }

    // Override me
    void onUpdate(Time t)
    {
    }

    import std.stdio;

    void update(Time t)
    {
        if (focused)
            processEvents();

        if (isLoading)
        {
            onLoad(t, assetManager.nextLoadingPercentage);
            isLoading = assetManager.isLoading;
        }
        else
        {
            if (!loaded)
            {
                assetManager.loadThreadUnsafePart();
                loaded = true;
                afterLoad();
                onLoad(t, 1.0f);
                canRender = true;
            }

            onUpdate(t);

            foreach(e; world)
            {
                e.update(t);
            }
        }
    }
}

/*
class EntityGroupSpatial: Owner, EntityGroup
{
    World world;

    this(World world, Owner owner)
    {
        super(owner);
        this.world = world;
    }

    int opApply(scope int delegate(Entity) dg)
    {
        int res = 0;
        foreach(size_t i, Entity e; world)
        {
            if (e.layer == EntityLayer.Spatial && !e.decal)
            {
                res = dg(e);
                if (res)
                    break;
            }
        }
        return res;
    }
}

class EntityGroupDecals: Owner, EntityGroup
{
    World world;

    this(World world, Owner owner)
    {
        super(owner);
        this.world = world;
    }

    int opApply(scope int delegate(Entity) dg)
    {
        int res = 0;
        foreach(size_t i, Entity e; world)
        {
            if (e.decal)
            {
                res = dg(e);
                if (res)
                    break;
            }
        }
        return res;
    }
}

class EntityGroupSpatialOpaque: Owner, EntityGroup
{
    World world;
    bool dynamic = true;

    this(World world, bool dynamic, Owner owner)
    {
        super(owner);
        this.world = world;
        this.dynamic = dynamic;
    }

    int opApply(scope int delegate(Entity) dg)
    {
        int res = 0;
        foreach(size_t i, Entity e; world)
        {
            if (e.layer == EntityLayer.Spatial && !e.decal)
            {
                bool transparent = false;
                
                if (e.material)
                    transparent = e.material.isTransparent;
                
                transparent = transparent || e.transparent || e.opacity < 1.0f;
                
                if (!transparent && e.dynamic == dynamic)
                {
                    res = dg(e);
                    if (res)
                        break;
                }
            }
        }
        return res;
    }
}

class EntityGroupSpatialTransparent: Owner, EntityGroup
{
    World world;

    this(World world, Owner owner)
    {
        super(owner);
        this.world = world;
    }

    int opApply(scope int delegate(Entity) dg)
    {
        int res = 0;
        foreach(size_t i, Entity e; world)
        {
            if (e.layer == EntityLayer.Spatial && !e.decal)
            {
                bool transparent = false;
                
                if (e.material)
                    transparent = e.material.isTransparent;
                
                transparent = transparent || e.transparent || e.opacity < 1.0f;
                
                if (transparent)
                {
                    res = dg(e);
                    if (res)
                        break;
                }
            }
        }
        return res;
    }
}

class EntityGroupBackground: Owner, EntityGroup
{
    World world;

    this(World world, Owner owner)
    {
        super(owner);
        this.world = world;
    }

    int opApply(scope int delegate(Entity) dg)
    {
        int res = 0;
        foreach(size_t i, Entity e; world)
        {
            if (e.layer == EntityLayer.Background)
            {
                res = dg(e);
                if (res)
                    break;
            }
        }
        return res;
    }
}

class EntityGroupForeground: Owner, EntityGroup
{
    World world;

    this(World world, Owner owner)
    {
        super(owner);
        this.world = world;
    }

    int opApply(scope int delegate(Entity) dg)
    {
        int res = 0;
        foreach(size_t i, Entity e; world)
        {
            if (e.layer == EntityLayer.Foreground)
            {
                res = dg(e);
                if (res)
                    break;
            }
        }
        return res;
    }
}

class EntityGroupLights: Owner, EntityGroup
{
    World world;

    this(World world, Owner owner)
    {
        super(owner);
        this.world = world;
    }

    int opApply(scope int delegate(Entity) dg)
    {
        int res = 0;
        foreach(size_t i, Entity e; world)
        {
            Light light = cast(Light)e;
            if (light)
            {
                res = dg(e);
                if (res)
                    break;
            }
        }
        return res;
    }
}

class EntityGroupSunLights: Owner, EntityGroup
{
    World world;

    this(World world, Owner owner)
    {
        super(owner);
        this.world = world;
    }

    int opApply(scope int delegate(Entity) dg)
    {
        int res = 0;
        foreach(size_t i, Entity e; world)
        {
            Light light = cast(Light)e;
            if (light)
            {
                if (light.type == LightType.Sun)
                {
                    res = dg(e);
                    if (res)
                        break;
                }
            }
        }
        return res;
    }
}

class EntityGroupAreaLights: Owner, EntityGroup
{
    World world;

    this(World world, Owner owner)
    {
        super(owner);
        this.world = world;
    }

    int opApply(scope int delegate(Entity) dg)
    {
        int res = 0;
        foreach(size_t i, Entity e; world)
        {
            Light light = cast(Light)e;
            if (light)
            {
                if (light.type == LightType.AreaSphere ||
                    light.type == LightType.AreaTube ||
                    light.type == LightType.Spot)
                {
                    res = dg(e);
                    if (res)
                        break;
                }
            }
        }
        return res;
    }
}
*/
