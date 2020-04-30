## Mono Repo Tools

### Setup CLI

 - clone this repository
 - run `pub get` at root
 - run `pub global activate --source path .` at root
   - Fix add to PATH warning if pub outputs one

You now have `melos` available as a command on your terminal.

### Workspace Setup

In a monorepo directory, e.g. the root of `flutterfire` repository run the following;

 - `melos workspace bootstrap` (`melos ws bs`)
    - initial bootstrap/creating of a workspace for a monorepo in the current directory.
 - `melos workspace pub get` (`melos ws p get`)
    - runs pub get on all monorepo plugins, and at the root of the workspace.
 - `melos workspace launch` (`melos ws l`)
    - opens the workspace in your IDE (hardcoded to Android Studio for now), workspace must have already been bootstrapped for this to launch
    
    
---

![image](https://user-images.githubusercontent.com/5347038/80675173-bb061480-8aab-11ea-808e-144b9b4a8fb5.png)

![image](https://user-images.githubusercontent.com/5347038/80675246-eb4db300-8aab-11ea-93cf-f920cbf8be70.png)

![image](https://user-images.githubusercontent.com/5347038/80675308-09b3ae80-8aac-11ea-83b7-d078c84fb143.png)
