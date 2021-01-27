<p align="center">
  <img src="https://static.invertase.io/assets/melos-logo.png" alt="Melos" /> <br /><br />
  <span>A tool for managing Dart projects with multiple packages, inspired by <a href="https://lerna.js.org">Lerna</a>.</span>
</p>

<p align="center">
  <a href="https://github.com/invertase/melos#readme-badge"><img src="https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square" alt="Melos" /></a>
</p>

---

- [Documentation](https://docs.page/invertase/melos)
- [License](/LICENSE)

## Install

```bash
dart pub global activate melos
```

## Local development setup

To setup and use this melos mono repo locally for the purposes of contributing, clone it and run the following commands from the root of the repository:

```bash
# Remove previous instances of melos:
dart pub global deactivate melos

# Activate 'melos' from path:
dart pub global activate --source="path" . --executable="melos"

# Confirm you now using a local development version:
melos --help
# You should now see a banner printed at the top of the help output similar to:
# ---------------------------------------------------------
# | You are running a local development version of melos. |
# ---------------------------------------------------------
```

## README Badge

Using Melos? Add a README badge to show it off:

[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

```markdown
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)
```

---

<p>
  <img align="left" width="75px" src="https://static.invertase.io/assets/invertase-logo-small.png">
  <p align="left">
    Built and maintained with 💛 by <a href="https://invertase.io">Invertase</a>.
  </p>
  <p align="left">
    <a href="https://invertase.link/discord"><img src="https://img.shields.io/discord/295953187817521152.svg?style=flat-square&colorA=7289da&label=Chat%20on%20Discord" alt="Chat on Discord"></a>
    <a href="https://twitter.com/invertaseio"><img src="https://img.shields.io/twitter/follow/invertaseio.svg?style=flat-square&colorA=1da1f2&colorB=&label=Follow%20on%20Twitter" alt="Follow on Twitter"></a>
  </p>
</p>

---
