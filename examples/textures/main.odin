package main

import eng "../../eng/core"
import "../../eng/core/const"
import "../../eng/core/util"
import "../../eng/core/input"
import "../../eng/render/draw"
import tx "../../eng/render/texture"

import "vendor:glfw"

tex: ^tx.Texture

main :: proc() {
    using eng

    init("window example",800,600)
    defer end()

    util.vsync(true)

    tex = tx.load("examples/textures/tex.png")
    defer tx.unload(tex)

    loop(
        proc() /* update */ {
            using input
            using glfw

            if is_key_press(KEY_ESCAPE) do stop()
        },
        proc() /* render */ {
            using draw
            clear(0,0,0)

            texture(tex, 0,0, const.__width,const.__height, [3]u8{255,0,0})
        }
    )
}

