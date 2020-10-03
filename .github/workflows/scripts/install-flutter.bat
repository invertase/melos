SET BRANCH=%1
CD /D %systemdrive%%homepath%
git clone https://github.com/flutter/flutter.git --depth 1 -b %BRANCH% _flutter

ECHO "%systemdrive%%homepath%\\_flutter\\bin">> %GITHUB_PATH%
ECHO "%systemdrive%%homepath%\\_flutter\\bin\\cache\\dart-sdk\\bin">> %GITHUB_PATH%
ECHO "%systemdrive%%homepath%\\_flutter\\Pub\\Cache\\bin">> %GITHUB_PATH%
ECHO "%LOCALAPPDATA%\\Pub\\Cache\\bin">> %GITHUB_PATH%
