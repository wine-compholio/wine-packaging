apt-get install -y libobjc-4.9-dev libffi-dev binfmt-support

{{
	# Those just create symlinks to our 3.5 package
	download("clang_3.5-25_i386.deb", "http://ftp.debian.org/debian/pool/main/l/llvm-defaults/clang_3.5-25_i386.deb",
             "28bd7dcbfe88c4b1b4cd6d37c65e37d518d609bb34e55d1b048d741cde7098e7")
	download("llvm_3.5-25_i386.deb", "http://ftp.debian.org/debian/pool/main/l/llvm-defaults/llvm_3.5-25_i386.deb",
             "f26dad6ef73581e796554e04d5f842c66d81023d0786c8ce63f42a3dcd39f4dc")
	download("llvm-runtime_3.5-25_i386.deb", "http://ftp.debian.org/debian/pool/main/l/llvm-defaults/llvm-runtime_3.5-25_i386.deb",
             "8465ec25612d4238aecba0edeb0636ae73dcde8dabaf00a32f6d0061c4b94cc5")
	download("llvm-dev_3.5-25_i386.deb", "http://ftp.debian.org/debian/pool/main/l/llvm-defaults/llvm-dev_3.5-25_i386.deb",
             "d6df4ca804b7f33c634f592e9eb971ccd2e1f3b573418fa64ef1c9e5e87dd899")
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
