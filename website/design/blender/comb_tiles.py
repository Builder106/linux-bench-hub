"""Render the comb's hex tiles: flat-top hex prisms seen straight down.

Run headless on the Mac (Cycles on Metal):
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P comb_tiles.py -- <output dir>
Each tile is a W x 0.866W image whose hexagon fills it exactly, so the page's
CSS hex clip lines up with the bevel. Tiles carry no data; numbers stay HTML.
"""
import math
import sys

import bpy

OUT = sys.argv[sys.argv.index("--") + 1]
WIDTH = 480
R = 1.0  # circumradius in metres; the flat-top hex is 2R wide and sqrt(3)R tall


def srgb(hex_color, alpha=1.0):
    def lin(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return (*[lin(int(hex_color[i:i + 2], 16)) for i in (1, 3, 5)], alpha)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    # Metal GPU on the Mac; the factory reset above clears preferences, so set it each time.
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "METAL"
    prefs.get_devices()
    gpus = [d for d in prefs.devices if d.type == "METAL"]
    for d in prefs.devices:
        d.use = d.type == "METAL"
    scene.cycles.device = "GPU" if gpus else "CPU"
    scene.cycles.samples = 96
    scene.cycles.use_denoising = True
    scene.render.resolution_x = WIDTH
    scene.render.resolution_y = round(WIDTH * math.sqrt(3) / 2)
    scene.render.image_settings.file_format = "WEBP"
    scene.render.image_settings.quality = 90
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("ground")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = srgb("#0a0507")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
    scene.world = world
    return scene


def material(name, base, roughness, transmission=0.0, ior=1.45, coat=0.0, noise=0.0, glow=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = srgb(base)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Transmission Weight"].default_value = transmission
    bsdf.inputs["IOR"].default_value = ior
    bsdf.inputs["Coat Weight"].default_value = coat
    bsdf.inputs["Emission Color"].default_value = srgb(base)
    bsdf.inputs["Emission Strength"].default_value = glow
    if noise:
        tex = nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = 9.0
        tex.inputs["Detail"].default_value = 6.0
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = noise
        links.new(tex.outputs["Fac"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def prism(mat, depth=0.35, bevel=0.07, segments=5, radius=R, smooth=True, rims_only=False):
    # Blender's six-sided cylinder is pointy-topped; a 30 degree turn makes it flat-topped.
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=radius, depth=depth,
                                        end_fill_type="TRIFAN" if rims_only else "NGON",
                                        location=(0, 0, depth / 2), rotation=(0, 0, math.pi / 6))
    obj = bpy.context.active_object
    mod = obj.modifiers.new("bevel", "BEVEL")
    mod.width = bevel
    mod.segments = segments
    mod.limit_method = "ANGLE"
    if rims_only:  # bevel the 90 degree top and bottom rims, keep the 60 degree side edges sharp
        mod.angle_limit = math.radians(75)
    if smooth:
        bpy.ops.object.shade_smooth()
    obj.data.materials.append(mat)
    return obj


def floor(look=None):
    bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 0, 0))
    bpy.context.active_object.data.materials.append(material("floor", **(look or {"base": "#0a0507", "roughness": 0.9})))


def camera():
    bpy.ops.object.camera_add(location=(0, 0, 6), rotation=(0, 0, 0))
    cam = bpy.context.active_object
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2 * R
    bpy.context.scene.camera = cam


def area(name, location, energy, color, size=3.0):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.active_object
    light.name = name
    light.data.energy = energy
    light.data.color = srgb(color)[:3]
    light.data.size = size
    light.visible_camera = False
    direction = -light.location
    light.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return light


def render(name):
    bpy.context.scene.render.filepath = f"{OUT}/tile-{name}.webp"
    bpy.ops.render.render(write_still=True)


def tile(name, look, lights, depth=0.35, rim=None, floor_look=None, **cut):
    reset()  # wipes every data-block, so the materials are built after it
    floor(floor_look)
    if rim:  # a thin emissive ring under the tile's edge
        prism(material(f"{name}-rim", **rim), depth=depth * 0.8, bevel=0.02, radius=R)
        prism(material(name, **look), depth=depth, radius=R * 0.972, **cut)
    else:
        prism(material(name, **look), depth=depth, **cut)
    camera()
    for light in lights:
        area(*light)
    render(name)


KEY = ("key", (-2.5, 2.5, 4.0), 260, "#fff2ec")
FILL = ("fill", (3.0, -2.0, 3.0), 60, "#ffd9cf")
OBSIDIAN = {"base": "#1c0b10", "roughness": 0.38, "coat": 0.4, "noise": 0.08}

tile("dark", OBSIDIAN, [KEY, FILL])
# Alternate test rows: a warmer, lighter stone so each zigzag row reads as one band.
tile("alt", {"base": "#3a1a1f", "roughness": 0.4, "coat": 0.4, "noise": 0.08}, [KEY, FILL])
tile("head", {"base": "#2a0e14", "roughness": 0.42, "coat": 0.3, "noise": 0.06}, [KEY, FILL])
tile("lit", OBSIDIAN, [KEY, FILL], rim={"base": "#cc342d", "roughness": 0.3, "glow": 2.2})
# The kernel: a cut ruby. Sharp facets each face a different light, so each gets its own tone.
tile("kernel", {"base": "#b0161c", "roughness": 0.22, "coat": 1.0, "ior": 1.76, "glow": 0.12},
     [("key", (-2.5, 2.5, 4.0), 520, "#fff2ec"), ("rim", (2.6, -2.2, 1.6), 380, "#f55a4d", 1.5)],
     depth=0.6, bevel=0.3, segments=2, smooth=False, rims_only=True)
print("rendered tiles to", OUT)
