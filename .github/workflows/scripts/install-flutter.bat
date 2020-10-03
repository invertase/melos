ECHO off
SET BRANCH=%1
ECHO on
CD /D %systemdrive%%homepath%
git clone https://github.com/flutter/flutter.git --depth 1 -b %BRANCH% _flutter

ECHO "::add-path::%systemdrive%%homepath%\_flutter\bin"
ECHO "::add-path::%LOCALAPPDATA%\Pub\Cache\bin"
ECHO "::add-path::%systemdrive%%homepath%\_flutter\Pub\Cache\bin"
ECHO "::add-path::%systemdrive%%homepath%\_flutter\bin\cache\dart-sdk\bin"
