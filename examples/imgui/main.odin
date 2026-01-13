package main

import "core:fmt"

import eng "../../eng/core"
import "../../eng/core/util"
import "../../eng/core/input"
import "../../eng/render/draw"

import "../../eng/lib/imgui"

import "vendor:glfw"

val_int:   i32
val_float: f32
val_col:   [3]f32

main :: proc() {
    using eng

    init("imgui example",800,600)
    defer end()

    util.vsync(true)

    loop(
        proc() /* update */ {
            using input
            using glfw

            if is_key_press(KEY_ESCAPE) do stop()
        },
        proc() /* render */ {
            using draw
            clear(0,0,0)

            using imgui

            // starts an imgui window
            if Begin("hi") { 
                Text("text")

                SliderInt("snappy slidey", &val_int, -10, 10)
                SliderFloat("smooth slidey", &val_float, -1, 1)

                InputInt("snappy setty", &val_int)

                smooth_setty_step :f32= 0.1
                InputFloat("smooth setty", &val_float, smooth_setty_step)

                if Button("print hi to the console") {
                    fmt.println("hi :)")
                }
                
                if TreeNode("dropdown") {
                    ColorPicker3("rainbow", &val_col)

                    // same situation as end
                    TreePop()
                }

                // must be called at end of imgui window if
                End() 
            }
        }
    )
}
