# Druntime + phobos (standalone) for zig-build (ABS)

> [!Note]
> A standalone runtime + stdlib (for easy cross-compile) using ABS is the goal of this project

**More info:** [issue#6: cross-compile with Druntime + Phobos2](https://github.com/kassane/anotherBuildStep/issues/6)

```bash
Project-Specific Options:
  -Dtarget=[string]            The CPU architecture, OS, and ABI to build for
  -Dcpu=[string]               Target CPU features to add or subtract
  -Ddynamic-linker=[string]    Path to interpreter on the target system
  -Doptimize=[enum]            Prioritize performance, safety, or binary size
                                 Supported Values:
                                   Debug
                                   ReleaseSafe
                                   ReleaseFast
                                   ReleaseSmall
  -Dlinkage=[enum]             Change linking mode (default: static)
                                 Supported Values:
                                   static
                                   dynamic
  -Dphobos=[bool]              Build phobos library (default: false)
```