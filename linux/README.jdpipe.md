# pandoc-jdpipe static artifacts

This repository can build a statically linked `pandoc-jdpipe` executable with
the patched Pandoc readers used by the jdpipe Apostrophe project and upstream
texmath's StarMath writer.
The executable keeps Pandoc's normal command-line behaviour but has a distinct
name, so installing it does not silently replace a distribution-provided
`pandoc`.

## Local build

Docker and a checkout of upstream texmath are required. The GitHub workflow
pins the compatible upstream revision recorded in
`linux/jdpipe-texmath-revision`. For local builds, texmath is expected at
`../texmath` by default:

```sh
make jdpipe-static
```

To use another checkout:

```sh
make jdpipe-static JDPIPE_TEXMATH_DIR=/path/to/texmath
```

The tarball and its SHA-256 checksum are written to `linux/artifacts/`.
Downloaded packages and compiled dependencies are retained in
`linux/cabal-cache/`, while local build products remain in `dist-newstyle/`.
Running `make jdpipe-static` again therefore resumes an interrupted build.
The release target uses `-O1` and limits both Cabal and the build container to
one CPU. In practice, the single GHC process for an `-O2` Pandoc build can
exceed 16 GiB even when module-level parallelism is disabled.

## User installation

The archive has a conventional `bin/` and `share/` layout beneath one top-level
directory:

```sh
mkdir -p ~/.local
tar -xzf pandoc-jdpipe-*.tar.gz -C ~/.local --strip-components=1
export PYPANDOC_PANDOC="$HOME/.local/bin/pandoc-jdpipe"
```

Users who want this build to override the system Pandoc can create their own
`~/.local/bin/pandoc` symlink.

## GitHub artifacts and releases

The `pandoc-jdpipe static Linux` workflow can be started manually to obtain a
GitHub Actions artifact. Pushing a tag matching `pandoc-jdpipe-v*` additionally
creates a GitHub Release and attaches the tarball and checksum:

```sh
git tag -a pandoc-jdpipe-v3.10-r1 -m "pandoc-jdpipe 3.10 r1"
git push origin pandoc-jdpipe-v3.10-r1
```

Before making a release, update `linux/jdpipe-texmath-revision` when the build
requires a newer compatible upstream texmath revision. The workflow checks out
that exact revision from `jgm/texmath`.
