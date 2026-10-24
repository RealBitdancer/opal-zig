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
    sizeof(OpalQueuedWrite),
    sizeof(OpalOperator),
    sizeof(OpalChannel),
    sizeof(Opal),
};

const size_t opal_abi_queued_write_offsets[] = {
    offsetof(OpalQueuedWrite, due),
    offsetof(OpalQueuedWrite, regNum),
    offsetof(OpalQueuedWrite, value),
};

const size_t opal_abi_operator_offsets[] = {
    offsetof(OpalOperator, envelopeStage),
    offsetof(OpalOperator, egOut),
    offsetof(OpalOperator, key),
    offsetof(OpalOperator, modSource),
    offsetof(OpalOperator, out),
    offsetof(OpalOperator, prevOut),
    offsetof(OpalOperator, phase),
    offsetof(OpalOperator, envelope),
    offsetof(OpalOperator, tremolo),
    offsetof(OpalOperator, vibrato),
    offsetof(OpalOperator, sustainHold),
    offsetof(OpalOperator, keyScaleRate),
    offsetof(OpalOperator, multiple),
    offsetof(OpalOperator, keyScaleLevel),
    offsetof(OpalOperator, totalLevel),
    offsetof(OpalOperator, attackRate),
    offsetof(OpalOperator, decayRate),
    offsetof(OpalOperator, sustainLevel),
    offsetof(OpalOperator, releaseRate),
    offsetof(OpalOperator, waveform),
};

const size_t opal_abi_channel_offsets[] = {
    offsetof(OpalChannel, opSlot),
    offsetof(OpalChannel, pairIndex),
    offsetof(OpalChannel, outSource),
    offsetof(OpalChannel, chanType),
    offsetof(OpalChannel, leftPan),
    offsetof(OpalChannel, rightPan),
    offsetof(OpalChannel, fNumber),
    offsetof(OpalChannel, block),
    offsetof(OpalChannel, latchedKeyScaleNumber),
    offsetof(OpalChannel, feedback),
    offsetof(OpalChannel, connection),
    offsetof(OpalChannel, outputEnable),
    offsetof(OpalChannel, algorithm),
};

const size_t opal_abi_opal_offsets[] = {
    offsetof(Opal, sampleRate),
    offsetof(Opal, sampleAccum),
    offsetof(Opal, lastOutput),
    offsetof(Opal, currOutput),
    offsetof(Opal, chan),
    offsetof(Opal, op),
    offsetof(Opal, timer),
    offsetof(Opal, timerControl),
    offsetof(Opal, timerCount),
    offsetof(Opal, status),
    offsetof(Opal, newMode),
    offsetof(Opal, pairEnable),
    offsetof(Opal, rhythmMode),
    offsetof(Opal, noteSelect),
    offsetof(Opal, tremoloDepth),
    offsetof(Opal, vibratoDepth),
    offsetof(Opal, waveSelectEnable),
    offsetof(Opal, compositeSine),
    offsetof(Opal, tremoloPosition),
    offsetof(Opal, tremoloLevel),
    offsetof(Opal, sampleCounter),
    offsetof(Opal, hiHatPhase),
    offsetof(Opal, cymbalPhase),
    offsetof(Opal, noise),
    offsetof(Opal, pendingRight),
    offsetof(Opal, chipSamples),
    offsetof(Opal, lastDue),
    offsetof(Opal, queueHead),
    offsetof(Opal, queueCount),
    offsetof(Opal, queue),
};

const int opal_abi_version[4] = {
    OPAL_VERSION_MAJOR,
    OPAL_VERSION_MINOR,
    OPAL_VERSION_PATCH,
    OPAL_VERSION,
};

#define OPAL_ABI_COUNT(array) (sizeof(array) / sizeof((array)[0]))

const size_t opal_abi_counts[4] = {
    OPAL_ABI_COUNT(opal_abi_queued_write_offsets),
    OPAL_ABI_COUNT(opal_abi_operator_offsets),
    OPAL_ABI_COUNT(opal_abi_channel_offsets),
    OPAL_ABI_COUNT(opal_abi_opal_offsets),
};
