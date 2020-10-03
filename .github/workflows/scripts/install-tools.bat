CD packages\melos\
CMD /K dart pub global activate --source=path .
CD /D %GITHUB_WORKSPACE%
melos bootstrap