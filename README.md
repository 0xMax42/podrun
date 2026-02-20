# podrun

`podrun` is a thin wrapper around `podman run` that enforces deterministic local image validation.

It ensures that a container image is rebuilt automatically if its declared build invariance does not match the build definition.

The validation is based on an **invariance hash** that must exist in:

1. The Quadlet `.build` unit (`Environment=INVARIANCE_HASH=...`)
2. The container image label (`io.0xmax42.invariance-hash`)

If the hashes differ — or if either side is missing — the build service is executed before running the container.

---

## Design Principles

`podrun` separates responsibilities strictly:

| Component             | Responsibility               |
| --------------------- | ---------------------------- |
| Quadlet `.build` unit | Declarative build definition |
| Container image       | Build result                 |
| Image label           | Invariance fingerprint       |
| podrun                | Consistency validation       |
| podman                | Container runtime            |

There are:

* No timestamp checks
* No registry lookups
* No implicit update mechanisms
* No heuristics

The system is fully deterministic.

---

## Naming Convention

The build unit is derived from the image name.

Example:

```
system.local/ocrmypdf-image:latest
```

Expected build unit:

```
ocrmypdf-image-build.service
```

The corresponding Quadlet file must be named:

```
ocrmypdf-image.build
```

Naming rule:

```
<image-name-without-tag>-build.service
```

---

## Requirements for the Quadlet `.build` Unit

The `.build` unit must:

1. Define `ImageTag=...`
2. Provide `INVARIANCE_HASH` as a `[Service]` environment variable
3. Pass that hash to `podman build` via `--build-arg`

### Example

```
# /etc/containers/systemd/users/ocrmypdf-image.build

[Unit]
Description=Build image for OCRmyPDF

[X-Build]
File=/usr/lib/ocrmypdf-image/Dockerfile
ImageTag=system.local/ocrmypdf-image:latest
SetWorkingDirectory=/usr/lib/ocrmypdf-image/
PodmanArgs=--build-arg VERSION=${IMAGE_VERSION} \
           --build-arg INVARIANCE_HASH=${INVARIANCE_HASH}

[Service]
Environment=IMAGE_VERSION=0.4.0
Environment=INVARIANCE_HASH=726e31944348130ecf821baad2604e1b6b6e252e72ecbb956aa969710816f1cb
Type=oneshot
```

Important:

* `INVARIANCE_HASH` must be defined in `[Service]`
* The same value must be passed to the build via `--build-arg`

---

## Requirements for the Dockerfile

The Dockerfile must:

1. Accept `INVARIANCE_HASH` as a build argument
2. Store it as an image label

### Example

```dockerfile
ARG INVARIANCE_HASH

LABEL io.0xmax42.invariance-hash="${INVARIANCE_HASH}"
```

The label key must be:

```
io.0xmax42.invariance-hash
```

---

## Validation Logic

When executing:

```
podrun IMAGE ...
```

The following happens:

1. If the image does not exist → build
2. If the image exists:

   * Read `INVARIANCE_HASH` from the build unit
   * Read label `io.0xmax42.invariance-hash` from the image
   * If either value is missing → build
   * If values differ → build
   * If values match → run container

This guarantees that the runtime image matches the declared build definition.

---

## Invariance Hash Strategy

The invariance hash must change whenever the build result would change.

Typical inputs:

* Dockerfile
* Architecture-specific Dockerfiles
* Template files
* Version files
* Additional build inputs

Example:

```
INVARIANCE_INPUTS="Dockerfile VERSION" ./invariance-hash.sh
```

The hash must be deterministic and reproducible.

---

## Rootless Operation

`podrun` assumes the build units are installed in the rootless Quadlet directory:

```
/etc/containers/systemd/users/
```

The generated unit must therefore be accessible via:

```
systemctl --user start <name>-build.service
```

---

## Summary

To use `podrun` correctly:

1. Name `.build` units consistently
2. Define `INVARIANCE_HASH` in `[Service]`
3. Pass the hash via `--build-arg`
4. Set the image label `io.0xmax42.invariance-hash`
5. Ensure the hash is deterministically generated

If these requirements are met, `podrun` guarantees that only images matching their declared build invariance are executed.
