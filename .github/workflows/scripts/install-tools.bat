CMD /C dart pub global activate --source=path packages/melos --executable=melos --overwrite
REM Workaround an issue when running global executables on Windows for the first time.
CMD /C melos > NUL
melos bootstrap