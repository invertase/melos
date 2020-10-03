CD packages\melos\
dart pub get
dart pub global activate --source=path .
CD /D %GITHUB_WORKSPACE%

melos bootstrap
ECHO "Bootstrap Completed"
