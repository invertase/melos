echo off
set BRANCH=%1
echo on
cd %systemdrive%%homepath%
git clone https://github.com/flutter/flutter.git --depth 1 -b $BRANCH _flutter

echo "::add-path::%systemdrive%%homepath%\_flutter\bin"
echo "::add-path::%LOCALAPPDATA%\Pub\Cache\bin"
echo "::add-path::%systemdrive%%homepath%\_flutter\Pub\Cache\bin"
echo "::add-path::%systemdrive%%homepath%\_flutter\bin\cache\dart-sdk\bin"
