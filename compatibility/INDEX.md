# Documentation index

This index maps the pinned Linux FXServer source build, its operator boundary, and the separate private package evidence. The [repository README](../README.md) carries current join evidence and V4/V5 state. Private deployment results do not change the public source branch or create a public binary download.

## Build and operate

- [Public build recipe](PUBLIC_BUILD.md): exact source and dependency pins, isolated repairs, packaging, verification, and remaining reproducibility work.
- [Installation boundary](INSTALL.md): host requirements, example configuration, restricted test operation, and update/rollback guidance.
- [Package records](PACKAGES.md): Full V2 and Runtime V3 contents, sizes, hashes, and validation scope.

## Evidence and limitations

- [Source updates](UPDATES.md): staged V4 and V5 files, provenance, and build limitations.
- [Test results](TEST_RESULTS.md): dated source-LAN test, private V4/V3 shutdown evidence, package checks, and what those tests do not establish.
- [Known issues](KNOWN_ISSUES.md): original shutdown fault, private fixes, remaining source integration, and authentication limits.

## Source and terms

- [Preserved upstream README](UPSTREAM_README.md): upstream project context.
- [Original tooling license](LICENSE.original-tooling.txt): present in this repository.
- Root files `LICENSE`, `LICENSES/`, and `THIRD_PARTY_NOTICES.md` retain upstream source and notice information.
- `SOURCE-GAPS.txt` is named in package records but is not present as a documentation file in this repository. Treat package inventory names as filenames, not links.
