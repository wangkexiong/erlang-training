@echo off
echo.

if "debug" == "%1" (
  @echo Compile with debug trace
  erlc +debug_info -DDEBUG ringbenchmark.erl
) else (
  @echo Compile w/o debug trace
  erlc +debug_info ringbenchmark.erl
)

echo Done
