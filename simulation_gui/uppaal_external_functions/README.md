# Uppaal External Functions

To make the external functions work with Uppaal you need to do two things:
1. Uppaal ships with its dependencies, including the shared libraries `libcrypto.so.3` and `libssl.so.3`. The problem with this is that these libraries will be installed in your system and, since they will probably be different versions, at runtime Uppaal will load its own libraries instead of the ones that you have compiled against! And you'll get errors. To fix this you can just delete the Uppal versions of the libraries in its `bin/` folder, it will fallback to the system level libraries.
2. In the system declarations you will need to set absolute path of your shared library
