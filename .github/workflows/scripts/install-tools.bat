CMD /C dart pub global activate --source=path . --executable=melos
REM Workaround an issue when running global executables on Windows for the first time.
CMD /C melos > NUL
melos bootstrap