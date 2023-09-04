{ stdenv
, lib
, runCommand
, toPythonModule
, fetchFromGitHub
, fetchpatch
, cmake
, python
, abseil-cpp
, protobuf
, pybind11
}: let
  # pybind11_protobuf requires proto_api.h from protobuf, which isn't installed
  # as part of the normal package. Upstream doesn't plan to fix this:
  # https://github.com/protocolbuffers/protobuf/issues/9464
  protoApiHeader = runCommand "protobuf-proto_api.h" { } ''
     mkdir -p "$out"/python/google/protobuf
     cp ${protobuf.src}/python/google/protobuf/proto_api.h "$out"/python/google/protobuf/proto_api.h
  '';
in toPythonModule (stdenv.mkDerivation rec {
  pname = "pybind11-protobuf";
  version = "unstable-20230828";

  src = fetchFromGitHub {
    owner = "pybind";
    repo = "pybind11_protobuf";
    rev = "3d7834b607758bbd2e3d210c6c478453922f20c0";
    hash = "sha256-7TZBFEDCzDBToaIf4tYouh+VBv4cLA4J7olK/aScmUE=";
  };

  patches = [
    /home/ben/Documents/Projects/pybind11_protobuf/0001-Install-libraries-with-CMake-and-export-targets.patch
  ];

  nativeBuildInputs = [
    cmake
    python
  ];

  buildInputs = [
    abseil-cpp
    protobuf
    pybind11
    protoApiHeader
  ];
  
  cmakeFlags = [
    "-Dprotobuf_SOURCE_DIR=${protoApiHeader}"
  ];

  preConfigure = ''
    echo NIX_CFLAGS_COMPILE=$NIX_CFLAGS_COMPILE
    echo NIX_LDFLAGS=$NIX_LDFLAGS
    unset NIX_CFLAGS_COMPILE
    unset NIX_LDFLAGS
  '';

  meta = with lib; {
    homepage = "https://github.com/pybind/pybind11_protobuf";
    description = "Pybind11 bindings for Google's Protocol Buffers";
    license = licenses.bsd3;
    maintainers = with maintainers; [ lopsided98 ];
  };
})
