//  Copyright (c) 2018 emekoi
//
//  This library is free software; you can redistribute it and/or modify it
//  under the terms of the MIT license. See LICENSE for details.
//

// [~] const char* cm_get_error(void);
// [x] void cm_init(int samplerate);
// [~] void cm_set_lock(cm_EventHandler lock);
// [x] void cm_set_master_gain(double gain);
// [ ] void cm_process(cm_Int16 *dst, int len);
// [ ] cm_Source* cm_new_source(const cm_SourceInfo *info);
// [ ] cm_Source* cm_new_source_from_file(const char *filename);
// [ ] cm_Source* cm_new_source_from_mem(void *data, int size);
// [ ] void cm_destroy_source(cm_Source *src);
// [ ] double cm_get_length(cm_Source *src);
// [ ] double cm_get_position(cm_Source *src);
// [ ] int cm_get_state(cm_Source *src);
// [ ] void cm_set_gain(cm_Source *src, double gain);
// [ ] void cm_set_pan(cm_Source *src, double pan);
// [ ] void cm_set_pitch(cm_Source *src, double pitch);
// [ ] void cm_set_loop(cm_Source *src, int loop);
// [ ] void cm_play(cm_Source *src);
// [ ] void cm_pause(cm_Source *src);
// [ ] void cm_stop(cm_Source *src);



const std = @import("std");
const Mutex = std.Mutex;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const math = std.math;
pub const Player = @import("player/index.zig");

const BUFFER_SIZE = 512;
const BUFFER_MASK = BUFFER_SIZE - 1;

const FX_BITS = 12;
const FX_UNIT = 1 << FX_BITS;

fn fxFromFloat(comptime T: type, f: T) isize {
    return f * FX_UNIT;
}

fn fxLerp(comptime T: type, a: T, b: T, p: T) T {
    return a + (((b - a) * p) >> FX_BITS);
}

fn clamp(comptime T: type, x: T, a: T, b: T) T {
    const max = math.max(T, a, b);
    const min = math.min(T, a, b);
    if (x > max) {
        return max;
    } else if (x < min) {
        return min;
    } else {
        return x;
    }
}

pub const State = enum {
    Stopped,
    Playing,
    Paused,
};

pub const EventHandler = fn(Event)!void;

pub const Event = union(enum) {
    Lock: void,
    Unlock: void,
    Rewind: void,
    Destroy: void,
    Samples: []const i16,
};


pub const SourceInfo = struct {
    handler: EventHandler,
    sample_rate: usize,
    length: usize,
};

pub const Source = struct {
    const Self = @This();

    mixer: *Mixer,
    next: ?*const Source,       // next source in list
    buffer: [BUFFER_SIZE]i16,   // internal buffer with raw stereo pcm
    handler: EventHandler,      // event handler
    sample_rate: usize,         // stream's native samplerate
    length: usize,              // stream's length in frames
    end: usize,                 // end index for the current play-through
    state: State,               // current state
    position: i64,              // current playhead position (fixed point)
    lgain, rgain: isize,        // left and right gain (fixed point)
    rate: isize,                // playback rate (fixed point)
    next_fill: isize,           // next frame idx where the buffer needs to be filled
    loop: bool,                 // whether the source will loop when `end` is reached
    rewind: bool,               // whether the source will rewind before playing
    active: bool,               // whether the source is part of `sources` list
    gain: f32,                  // gain set by `setGain()`
    pan: f32,                   // pan set by `setPan()`

    fn new(mixer: *Mixer, info: SourceInfo) Self {
        return undefined;
    }

    fn rewindSource(self: *Self) void {
        self.handler(Event {
            .Rewind = {},
        });
        self.position = 0;
        self.rewind = false;
        self.end = self.length;
        self.next_fill = 0;
    }

    fn fillBuffer(self: *Self, offset: usize, length: usize) void {
        const start = offset;
        const end = start + length;
        self.handler(Event {
            .Samples = self.buffer[start..end],
        });
    }

    fn process(self: *Self) void {
        const dst = self.mixer.buffer;

        // do rewind if flag is set
        if (self.rewind) {
            self.rewindSource();
        }

        // don't process if not playing
        switch (self.state) {
            State.Paused => return,
            else => {},
        }

        // process audio
        while (length > 0) {
            // get current position frame
            const frame = self.position >> FX_BITS;
        }
    }
};


pub const Mixer = struct {
    const Self = @This();

    lock: Mutex,                // mutex
    sources: ArrayList(Source), // linked list of active sources
    buffer: [BUFFER_SIZE]i32,   // internal master buffer
    sample_rate: isize,         // master samplerate
    gain: isize,                // master gain (fixed point)

    pub fn init(allocator: *Allocator, sample_rate: isize) Self {
        return Self {
            .sample_rate = sample_rate,
            .lock = Mutex.init(),
            .sources = ArrayList.init(allocator),
            .gain = FX_UNIT,
        };
    }

    pub fn setGain(self: *Self, gain: f32) void {
        self.gain = fxFromFloat(f32, gain);
    }
};
