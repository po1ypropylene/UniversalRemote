# Bundled open-source components

| Component | Pinned release | License | Upstream |
|---|---|---|---|
| FreeRDP / WinPR | 3.32.1 | Apache-2.0 | https://github.com/FreeRDP/FreeRDP |
| libssh2 | 1.11.1 | BSD-3-Clause | https://github.com/libssh2/libssh2 |
| OpenSSL | 3.6.5 | Apache-2.0 | https://github.com/openssl/openssl |
| SwiftTerm | 1.20.0 | MIT | https://github.com/migueldeicaza/SwiftTerm |

The adjacent files contain upstream license texts. SwiftTerm is resolved through
Swift Package Manager; the others are built from pinned source revisions by
`scripts/prepare-dependencies.sh`. Apple frameworks and the system zlib are
provided by macOS.

FreeRDP includes Google's CPU-feature detection code; its NOTICE and license
are also included below. Test-only Paramiko is not included in the application.
