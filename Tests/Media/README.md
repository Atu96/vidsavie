# Synthetic codec fixtures

These tiny two-frame 128×96 AV1/VP9 inputs were generated from FFmpeg's lavfi `testsrc2` pattern. No social-platform download or user media was used. They are decoder regression inputs for `Scripts/test-media-toolchain.sh`, not representative performance benchmarks or a claim of all codec/profile support.

Regenerate with the script's optional third argument pointing to a reference FFmpeg build containing libaom-av1 and libvpx-vp9 encoders. The app-specific reviewed profile only needs their decoding capability.
