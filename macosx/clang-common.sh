apt-get install -y libobjc-4.9-dev libffi-dev binfmt-support

{{
	# Those just create symlinks to our 3.5 package
	download("clang_3.5-25_i386.deb", "http://ftp.debian.org/debian/pool/main/l/llvm-defaults/clang_3.5-25_i386.deb")
	download("llvm_3.5-25_i386.deb", "http://ftp.debian.org/debian/pool/main/l/llvm-defaults/llvm_3.5-25_i386.deb")
	download("llvm-runtime_3.5-25_i386.deb", "http://ftp.debian.org/debian/pool/main/l/llvm-defaults/llvm-runtime_3.5-25_i386.deb")
	download("llvm-dev_3.5-25_i386.deb", "http://ftp.debian.org/debian/pool/main/l/llvm-defaults/llvm-dev_3.5-25_i386.deb")
}}

dpkg -i /build/source/deps/libclang-common-3.5-dev_3.5-10~jessie_i386.deb \
        /build/source/deps/libclang1-3.5_3.5-10~jessie_i386.deb \
        /build/source/deps/libllvm3.5_3.5-10~jessie_i386.deb \
        /build/source/deps/llvm-3.5-dev_3.5-10~jessie_i386.deb \
        /build/source/deps/llvm-3.5_3.5-10~jessie_i386.deb \
        /build/source/deps/llvm-3.5-runtime_3.5-10~jessie_i386.deb \
        /build/source/deps/clang-3.5_3.5-10~jessie_i386.deb \
        /build/source/clang_3.5-25_i386.deb \
        /build/source/llvm_3.5-25_i386.deb \
        /build/source/llvm-runtime_3.5-25_i386.deb \
        /build/source/llvm-dev_3.5-25_i386.deb

rm -f clang_3.5-25_i386.deb \
      llvm_3.5-25_i386.deb \
      llvm-runtime_3.5-25_i386.deb \
      llvm-dev_3.5-25_i386.deb
