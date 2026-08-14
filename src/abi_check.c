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
    offsetof(OpalOperator, slotIndex),
    offsetof(OpalOperator, chanIndex),
    offsetof(OpalOperator, modSource),
    offsetof(OpalOperator, phase),
    offsetof(OpalOperator, phaseOut),
    offsetof(OpalOperator, phaseReset),
    offsetof(OpalOperator, waveform),
    offsetof(OpalOperator, freqMultTimes2),
    offsetof(OpalOperator, envelopeStage),
    offsetof(OpalOperator, envelopeLevel),
    offsetof(OpalOperator, egOut),
    offsetof(OpalOperator, egKsl),
    offsetof(OpalOperator, outputLevel),
    offsetof(OpalOperator, attackRate),
    offsetof(OpalOperator, decayRate),
    offsetof(OpalOperator, sustainLevel),
    offsetof(OpalOperator, releaseRate),
    offsetof(OpalOperator, keyScaleReg),
    offsetof(OpalOperator, key),
    offsetof(OpalOperator, out),
    offsetof(OpalOperator, prevOut),
    offsetof(OpalOperator, fbMod),
    offsetof(OpalOperator, keyScaleRate),
    offsetof(OpalOperator, sustainMode),
    offsetof(OpalOperator, tremoloEnable),
    offsetof(OpalOperator, vibratoEnable),
};

const size_t opal_abi_channel_offsets[] = {
    offsetof(OpalChannel, opSlot),
    offsetof(OpalChannel, chanIndex),
    offsetof(OpalChannel, pairIndex),
    offsetof(OpalChannel, outSource),
    offsetof(OpalChannel, chanType),
    offsetof(OpalChannel, freq),
    offsetof(OpalChannel, octave),
    offsetof(OpalChannel, keyScaleNumber),
    offsetof(OpalChannel, feedbackShift),
    offsetof(OpalChannel, modulationType),
    offsetof(OpalChannel, alg),
    offsetof(OpalChannel, cha),
    offsetof(OpalChannel, chb),
    offsetof(OpalChannel, chc),
    offsetof(OpalChannel, chd),
    offsetof(OpalChannel, leftPan),
    offsetof(OpalChannel, rightPan),
};

const size_t opal_abi_opal_offsets[] = {
    offsetof(Opal, sampleRate),
    offsetof(Opal, sampleAccum),
    offsetof(Opal, lastOutput),
    offsetof(Opal, currOutput),
    offsetof(Opal, mixBuffRight),
    offsetof(Opal, chan),
    offsetof(Opal, op),
    offsetof(Opal, chipTimer),
    offsetof(Opal, tremoloPos),
    offsetof(Opal, tremoloLevel),
    offsetof(Opal, tremoloShift),
    offsetof(Opal, vibPos),
    offsetof(Opal, vibShift),
    offsetof(Opal, egTimer),
    offsetof(Opal, egState),
    offsetof(Opal, egAdd),
    offsetof(Opal, egTimerLo),
    offsetof(Opal, egTimerRem),
    offsetof(Opal, noteSel),
    offsetof(Opal, opl3Enabled),
    offsetof(Opal, rhythmMode),
    offsetof(Opal, waveformSelect),
    offsetof(Opal, compositeSineWave),
    offsetof(Opal, noise),
    offsetof(Opal, rmHhBit2),
    offsetof(Opal, rmHhBit3),
    offsetof(Opal, rmHhBit7),
    offsetof(Opal, rmHhBit8),
    offsetof(Opal, rmTcBit3),
    offsetof(Opal, rmTcBit5),
    offsetof(Opal, rhythmReg),
    offsetof(Opal, timer),
    offsetof(Opal, timerControl),
    offsetof(Opal, timerCount),
    offsetof(Opal, status),
    offsetof(Opal, writeBuf),
    offsetof(Opal, writeBufSampleCount),
    offsetof(Opal, writeBufCur),
    offsetof(Opal, writeBufLast),
    offsetof(Opal, writeBufLastTime),
};

const int opal_abi_version[4] = {
    OPAL_VERSION_MAJOR,
    OPAL_VERSION_MINOR,
    OPAL_VERSION_PATCH,
    OPAL_VERSION,
};

#define OPAL_ABI_COUNT(array) (sizeof(array) / sizeof((array)[0]))

const size_t opal_abi_counts[4] = {
    OPAL_ABI_COUNT(opal_abi_write_buf_offsets),
    OPAL_ABI_COUNT(opal_abi_operator_offsets),
    OPAL_ABI_COUNT(opal_abi_channel_offsets),
    OPAL_ABI_COUNT(opal_abi_opal_offsets),
};
