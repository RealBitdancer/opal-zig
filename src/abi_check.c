/*
    Copyright (c) 2026 Bitdancer (github.com/RealBitdancer).
    SPDX-License-Identifier: MIT

    Exports sizeof and offsetof data for every public opal struct so the Zig
    test suite can verify its mirrored layouts against the C compiler. The
    entries must stay in header declaration order.
*/

#include <opal/opal.h>

#include <stddef.h>

const size_t opal_abi_sizes[4] = {
    sizeof(OpalWriteBuf),
    sizeof(OpalOperator),
    sizeof(OpalChannel),
    sizeof(Opal),
};

const size_t opal_abi_write_buf_offsets[] = {
    offsetof(OpalWriteBuf, time),
    offsetof(OpalWriteBuf, reg),
    offsetof(OpalWriteBuf, data),
};

const size_t opal_abi_operator_offsets[] = {
    offsetof(OpalOperator, Master),
    offsetof(OpalOperator, Chan),
    offsetof(OpalOperator, SlotIndex),
    offsetof(OpalOperator, Phase),
    offsetof(OpalOperator, PhaseOut),
    offsetof(OpalOperator, PhaseReset),
    offsetof(OpalOperator, Waveform),
    offsetof(OpalOperator, FreqMultTimes2),
    offsetof(OpalOperator, EnvelopeStage),
    offsetof(OpalOperator, EnvelopeLevel),
    offsetof(OpalOperator, EgOut),
    offsetof(OpalOperator, EgKsl),
    offsetof(OpalOperator, OutputLevel),
    offsetof(OpalOperator, AttackRate),
    offsetof(OpalOperator, DecayRate),
    offsetof(OpalOperator, SustainLevel),
    offsetof(OpalOperator, ReleaseRate),
    offsetof(OpalOperator, KeyScaleReg),
    offsetof(OpalOperator, Key),
    offsetof(OpalOperator, Out),
    offsetof(OpalOperator, PrevOut),
    offsetof(OpalOperator, FbMod),
    offsetof(OpalOperator, Mod),
    offsetof(OpalOperator, KeyScaleRate),
    offsetof(OpalOperator, SustainMode),
    offsetof(OpalOperator, TremoloEnable),
    offsetof(OpalOperator, VibratoEnable),
};

const size_t opal_abi_channel_offsets[] = {
    offsetof(OpalChannel, Op),
    offsetof(OpalChannel, Master),
    offsetof(OpalChannel, ChanIndex),
    offsetof(OpalChannel, ChanType),
    offsetof(OpalChannel, Freq),
    offsetof(OpalChannel, Octave),
    offsetof(OpalChannel, KeyScaleNumber),
    offsetof(OpalChannel, FeedbackShift),
    offsetof(OpalChannel, ModulationType),
    offsetof(OpalChannel, Alg),
    offsetof(OpalChannel, ChannelPair),
    offsetof(OpalChannel, OutPtr),
    offsetof(OpalChannel, Cha),
    offsetof(OpalChannel, Chb),
    offsetof(OpalChannel, Chc),
    offsetof(OpalChannel, Chd),
    offsetof(OpalChannel, LeftPan),
    offsetof(OpalChannel, RightPan),
};

const size_t opal_abi_opal_offsets[] = {
    offsetof(Opal, SampleRate),
    offsetof(Opal, SampleAccum),
    offsetof(Opal, LastOutput),
    offsetof(Opal, CurrOutput),
    offsetof(Opal, MixBuffRight),
    offsetof(Opal, Chan),
    offsetof(Opal, Op),
    offsetof(Opal, ZeroMod),
    offsetof(Opal, ChipTimer),
    offsetof(Opal, TremoloPos),
    offsetof(Opal, TremoloLevel),
    offsetof(Opal, TremoloShift),
    offsetof(Opal, VibPos),
    offsetof(Opal, VibShift),
    offsetof(Opal, EgTimer),
    offsetof(Opal, EgState),
    offsetof(Opal, EgAdd),
    offsetof(Opal, EgTimerLo),
    offsetof(Opal, EgTimerRem),
    offsetof(Opal, NoteSel),
    offsetof(Opal, OPL3Enabled),
    offsetof(Opal, RhythmMode),
    offsetof(Opal, WaveformSelect),
    offsetof(Opal, CompositeSineWave),
    offsetof(Opal, Noise),
    offsetof(Opal, RmHhBit2),
    offsetof(Opal, RmHhBit3),
    offsetof(Opal, RmHhBit7),
    offsetof(Opal, RmHhBit8),
    offsetof(Opal, RmTcBit3),
    offsetof(Opal, RmTcBit5),
    offsetof(Opal, RhythmReg),
    offsetof(Opal, Timer),
    offsetof(Opal, TimerControl),
    offsetof(Opal, TimerCount),
    offsetof(Opal, Status),
    offsetof(Opal, WriteBuf),
    offsetof(Opal, WriteBufSampleCnt),
    offsetof(Opal, WriteBufCur),
    offsetof(Opal, WriteBufLast),
    offsetof(Opal, WriteBufLastTime),
};

#define OPAL_ABI_COUNT(array) (sizeof(array) / sizeof((array)[0]))

const size_t opal_abi_counts[4] = {
    OPAL_ABI_COUNT(opal_abi_write_buf_offsets),
    OPAL_ABI_COUNT(opal_abi_operator_offsets),
    OPAL_ABI_COUNT(opal_abi_channel_offsets),
    OPAL_ABI_COUNT(opal_abi_opal_offsets),
};
