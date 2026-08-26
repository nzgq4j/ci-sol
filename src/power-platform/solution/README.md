# Solution package

**Empty by design.**

A Power Platform solution `.zip` is a build artefact produced by exporting from a real Dev
environment after the flows are built from the specifications in `../flow-specifications/`.

Hand-writing an archive here would produce a file that imports incorrectly or not at all, and would
misrepresent tenant work as complete. `Deploy-DmsPowerPlatform.ps1` reports the missing package as a
blocking plan action, and a test asserts that no `.zip` exists under `src/power-platform/`.

## When the solution exists

1. Build the five flows in Dev inside one solution, from the specifications.
2. Add environment variables and connection references — no hard-coded values.
3. Export **managed** for Test and Prod; export unmanaged source for review.
4. Unpack with `pac solution unpack` and commit the unpacked source so changes are reviewable.
5. Place the managed `.zip` here (or publish it as a pipeline artefact) and run the deployment script.
