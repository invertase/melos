SET BRANCH=%1
CD /D %systemdrive%%homepath%
git clone https://github.com/flutter/flutter.git --depth 1 -b %BRANCH% _flutter

%systemdrive%%homepath%\_flutter\bin\flutter doctor
%systemdrive%%homepath%\_flutter\bin\dart --version

ECHO "##[add-path]%systemdrive%%homepath%\\_flutter\\bin"
ECHO "##[add-path]%systemdrive%%homepath%\\_flutter\\bin\\cache\\dart-sdk\\bin"
ECHO "##[add-path]%systemdrive%%homepath%\\_flutter\\Pub\\Cache\\bin"
ECHO "##[add-path]%LOCALAPPDATA%\\Pub\\Cache\\bin"


DIR %systemdrive%%homepath%\_flutter\bin
DIR %systemdrive%%homepath%\_flutter\bin\cache\dart-sdk\bin