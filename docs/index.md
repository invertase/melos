<Image src="https://static.invertase.io/assets/melos-logo.png" alt="Melos" zoom={false} caption="A tool for managing Dart projects with multiple packages." />

## About

Melos is a [CLI](https://en.wikipedia.org/wiki/Command-line_interface) tool used to help manage Dart projects with multiple packages (also known as mono-repos). It is currently still in active development however is in use on projects such as [FlutterFire](https://github.com/FirebaseExtended/flutterfire).

Splitting up large code bases into separate independently versioned packages is extremely useful for code sharing. However, making changes across many repositories is messy and difficult to track, and testing across repositories gets complicated. Melos helps solve these issues by allowing multiple packages to work together within one repository, whilst being totally independent of each other. Features include:

- Automatic versioning & changelog generation.
- Automated publishing of packages to pub.dev.
- Local package linking and installation.
- Executing simultaneous commands across packages.
- Listing of local packages & their dependencies.

Melos also works great on CI/CD environments to help automate complex tasks and challenges.

## Projects using Melos

The following projects are using Melos:

- [FirebaseExtended/flutterfire](https://github.com/FirebaseExtended/flutterfire)
- [aws-amplify/amplify-flutter](https://github.com/aws-amplify/amplify-flutter)
- [fluttercommunity/plus_plugins](https://github.com/fluttercommunity/plus_plugins)

> [Submit a PR](https://github.com/invertase/melos/edit/master/docs/README.md) to add your project to the list.

## License

See [LICENSE](https://github.com/invertase/melos/blob/master/LICENSE) for more information.

---

<div style={{ display: 'flex' }}>
  <img width="75px" src="https://static.invertase.io/assets/invertase-logo-small.png" />
  <div>
    <p>
      Built and maintained with 💛 by <a href="https://invertase.io">Invertase</a>.
    </p>
    <p>
      <a href="https://invertase.link/discord"><img src="https://img.shields.io/discord/295953187817521152.svg?style=flat-square&colorA=7289da&label=Chat%20on%20Discord" alt="Chat on Discord" /></a> &nbsp;
      <a href="https://twitter.com/invertaseio"><img src="https://img.shields.io/twitter/follow/invertaseio.svg?style=flat-square&colorA=1da1f2&colorB=&label=Follow%20on%20Twitter" alt="Follow on Twitter" /></a>
  </p>
  </div>
</div>
