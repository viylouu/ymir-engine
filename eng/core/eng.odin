package eng // shorthand for engine

import "time"
import "error"
import "const"
import "input"
import "callback"
import "../sound"
import "../render/draw"
import "../render/shader"

import "core:fmt"
import "core:strings"
import "core:strconv"

import im "../lib/imgui"
import imfw "../lib/imgui/glfw"
import imgl "../lib/imgui/opengl3"

import "vendor:glfw"
import "vendor:stb/image"
import gl "vendor:OpenGL"

WF_DEFAULT :: WF_SOUND_LIB | WF_IMGUI

WF_CONST_SCALE   :: 1 << 1    // makes it so the draw area will not change
WF_RESIZABLE     :: 1 << 2    // makes the window able to be resized
WF_IMGUI         :: 1 << 3    // whether or not to initialize imgui, also for some reason eng segfaults on end without this
WF_SOUND_LIB     :: 1 << 4    // allows you to use the eng/sound stuff instead of raw openal or whatever
WF_PIXEL_PERFECT :: 1 << 5    // pixelizes the viewport at the area scale, using this forces const scale

@private
_pptex: u32
@private
_ppvao: u32
@private
_pprog: u32

imgui_ver_string:  string

scale_window :: proc(scale: f32) {
    using glfw
    using const
    SetWindowSize(__handle, i32(f32(__area_width)*scale), i32(f32(__area_height)*scale))
}

// flags can be specified using the consts in the format: WF_FLAG_NAME and bit-or-ing the flags together 
init :: proc(title: cstring, width,height: i32, flags: int = WF_DEFAULT) {
    using glfw
    using const

    error.critical("glfw is not being very happy >:(", !bool(Init()))

    // could be better by using log2 with variables but im too lazy to do that
    const.wflag_const_scale   = bool(flags >> 1  & 1)
    const.wflag_resizable     = bool(flags >> 2  & 1)
    const.wflag_imgui         = bool(flags >> 3  & 1)
    const.wflag_sound_lib     = bool(flags >> 4  & 1)
    const.wflag_pixel_perfect = bool(flags >> 5  & 1)

    if const.wflag_pixel_perfect do const.wflag_const_scale = true

    WindowHint(RESIZABLE,             const.wflag_resizable? TRUE : FALSE)
    WindowHint(OPENGL_FORWARD_COMPAT, TRUE)
	WindowHint(OPENGL_PROFILE,        OPENGL_CORE_PROFILE)
    WindowHint(CONTEXT_VERSION_MAJOR, const.GL_MAJOR)
    WindowHint(CONTEXT_VERSION_MINOR, const.GL_MINOR)
    //WindowHint(FLOATING,              TRUE)

    const.__handle = CreateWindow(width,height,title, nil,nil)
    error.critical("the window is being silly, wattesigma", const.__handle == nil)

    MakeContextCurrent(__handle)
    SwapInterval(0)
    SetFramebufferSizeCallback(__handle, callback.__fbcb_size)

    gl.load_up_to(int(const.GL_MAJOR), const.GL_MINOR, gl_set_proc_address)
    //fmt.println("gl ver: ", gl.GetString(gl.VERSION))

    if const.wflag_imgui {
        im.CHECKVERSION()
        im.CreateContext()

        im.StyleColorsDark()

        imfw.InitForOpenGL(__handle, true)
        
        buf: [2]byte
        imgui_ver_string = strings.concatenate ([]string { 
                "#version ", 
                strconv.write_int(buf[:], const.GL_MAJOR, 10),
                strconv.write_int(buf[:], const.GL_MINOR, 10),
                "0 core"
            })

        imgl.Init(strings.unsafe_string_to_cstring(imgui_ver_string))
    }

    __width, __height = width, height
    __area_width  = width
    __area_height = height

    gl.Viewport(0,0,__area_width,__area_height)

    // fixes a bug where drawing doesent show up on windows until window is resized
    SetWindowSize(__handle, width + 1, height)
    SetWindowSize(__handle, width, height)

    input.load_mappings()

	draw.init(f32(__area_width),f32(__area_height))

    if const.wflag_sound_lib do sound.init()

    if const.wflag_pixel_perfect { 
        gl.GenFramebuffers(1, &const.__ppfbo) 
        gl.BindFramebuffer(gl.FRAMEBUFFER, const.__ppfbo)

        gl.GenTextures(1, &_pptex)
        gl.BindTexture(gl.TEXTURE_2D, _pptex)

        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width,height, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)

        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

        gl.BindTexture(gl.TEXTURE_2D, 0)

        gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, _pptex, 0)

        error.critical("framebuffer is not complete!", gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE)
        gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

        gl.GenVertexArrays(1, &_ppvao) // dummy (thicc} vao

        pprog_vert_data := #load("../../data/shaders/eng/buf.vert", cstring)
        pprog_frag_data := #load("../../data/shaders/eng/buf.frag", cstring)
        _pprog = shader.load_program_from_src(&pprog_vert_data, &pprog_frag_data)
    }
}

loop :: proc(update,render: proc()) {
    using time
    using input
    using const

    time = glfw.GetTime()

    lastTime: f64
    for !glfw.WindowShouldClose(__handle) {
        glfw.PollEvents()
		poll(__handle)

        /* time */ { 
            now      := glfw.GetTime()
            act_delta = now - lastTime
            act_time  = now
            lastTime  = now

            act_delta32 = f32(act_delta)
            act_time32  = f32(act_time)

            delta = get_timescale() * act_delta
            time += delta

            delta32 = f32(delta)
            time32  = f32(time)
        }

        /* scale stuff */ {
            __width  = callback.__width
            __height = callback.__height

            if !const.wflag_const_scale {
                __area_width  = __width
                __area_height = __height
            } 

            mouse_x /= f32(__width)
            mouse_y /= f32(__height)
            mouse_x *= f32(__area_width)
            mouse_y *= f32(__area_height)
        }

        draw.update(f32(__area_width),f32(__area_height))

        if const.wflag_imgui {
            imfw.NewFrame()
            imgl.NewFrame()
            im.NewFrame()
        }

        if const.wflag_pixel_perfect {
            using gl
            BindFramebuffer(FRAMEBUFFER, const.__ppfbo)
            Viewport(0,0, const.__area_width,const.__area_height)
        }

        update()
        render()

        draw.flush()

        if const.wflag_pixel_perfect {
            using gl
            BindFramebuffer(FRAMEBUFFER, 0)
            Viewport(0,0, const.__width,const.__height)

            ClearColor(1,0,1,1)
            Clear(COLOR_BUFFER_BIT)

            UseProgram(_pprog)
            BindVertexArray(_ppvao)
            Disable(DEPTH_TEST)
            BindTexture(TEXTURE_2D, _pptex)
            DrawArrays(TRIANGLES, 0, 6)
        }

        if const.wflag_sound_lib do sound.update()

        if const.wflag_imgui {
            im.Render()
            imgl.RenderDrawData(im.GetDrawData())
        }

        glfw.SwapBuffers(const.__handle)
    }
}

end :: proc() {
    using glfw
    using const

    if const.wflag_pixel_perfect {
        gl.DeleteTextures(1, &_pptex)
        gl.DeleteFramebuffers(1, &__ppfbo)
    }

    if const.wflag_imgui {
        imgl.Shutdown()
        imfw.Shutdown()
        im.DestroyContext()

        delete(imgui_ver_string)
    }

    if const.wflag_sound_lib {
        sound.stfu()
        sound.end()
    }

    draw.end()

    // just being safe
    SetKeyCallback(__handle, nil)
    SetCharCallback(__handle, nil)
    SetCursorPosCallback(__handle, nil)
    SetMouseButtonCallback(__handle, nil)
    SetScrollCallback(__handle, nil)
    SetWindowCloseCallback(__handle, nil)
    SetFramebufferSizeCallback(__handle, nil)

    MakeContextCurrent(nil)

    DestroyWindow(__handle)

    Terminate()
}

stop :: proc() {
    using glfw
    SetWindowShouldClose(const.__handle, true)
}
