cd govarnam
make library-mac-universal
install_name_tool -id @executable_path/../Frameworks/libgovarnam.dylib libgovarnam.dylib || exit 1
cp ./libgovarnam.dylib ../
