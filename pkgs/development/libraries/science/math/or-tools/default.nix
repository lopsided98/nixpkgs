{ abseil-cpp
, bzip2
, cbc
, cmake
, eigen
, ensureNewerSourcesForZipFilesHook
, fetchFromGitHub
, glpk
, lib
, pkg-config
, protobuf
, python
, re2
, stdenv
, swig4
, unzip
, zlib
, pythonSupport ? false
}:

stdenv.mkDerivation rec {
  pname = "or-tools";
  version = "9.7";

  src = fetchFromGitHub {
    owner = "google";
    repo = "or-tools";
    rev = "v${version}";
    hash = "sha256-eHukf6TbY2dx7iEf8WfwfWsjDEubPtRO02ju0kHtASo=";
  };

  # or-tools normally attempts to build Protobuf for the build platform when
  # cross-compiling. Instead, just tell it where to find protoc.
  postPatch = ''
    echo "set(PROTOC_PRG $(type -p protoc))" > cmake/host.cmake
  '';

  cmakeFlags = [
    "-DBUILD_DEPS=OFF"
    "-DUSE_GLPK=ON"
    "-DUSE_SCIP=OFF"
  ] ++ lib.optionals pythonSupport [
    "-DBUILD_PYTHON=ON"
    "-DBUILD_pybind11=OFF"
    "-DBUILD_pybind11_protobuf=OFF"
    "-DFETCH_PYTHON_DEPS=OFF"
    "-DPython3_EXECUTABLE=${python.pythonForBuild.interpreter}"
  ] ++ lib.optionals stdenv.isDarwin [ "-DCMAKE_MACOSX_RPATH=OFF" ];
  nativeBuildInputs = [
    cmake
    pkg-config
    protobuf
  ] ++ lib.optionals pythonSupport ([
    ensureNewerSourcesForZipFilesHook
    unzip
    python.pythonForBuild
    swig4
  ] ++ (with python.pythonForBuild.pkgs; [
    pip
    mypy-protobuf
  ]));
  buildInputs = [
    bzip2
    cbc
    eigen
    glpk
    re2
    zlib
  ] ++ lib.optionals pythonSupport (with python.pkgs; [
    absl-py
    pybind11
    pybind11-protobuf
    setuptools
    wheel
  ]);
  propagatedBuildInputs = [
    abseil-cpp
    protobuf
  ] ++ lib.optionals pythonSupport [
    (python.pkgs.protobuf.override { protobuf = protobuf; })
    python.pkgs.numpy
  ];
  nativeCheckInputs = lib.optionals pythonSupport (with python.pkgs; [
    virtualenv
    pandas
    matplotlib
    pytest
    scipy
  ]);

  doCheck = true;

  # This extra configure step prevents the installer from littering
  # $out/bin with sample programs that only really function as tests,
  # and disables the upstream installation of a zipped Python egg that
  # can’t be imported with our Python setup.
  installPhase = ''
    cmake . -DBUILD_EXAMPLES=OFF -DBUILD_PYTHON=OFF -DBUILD_SAMPLES=OFF
    cmake --install .
  '' + lib.optionalString pythonSupport ''
    pip install --prefix="$python" python/
  '';

  outputs = [ "out" ] ++ lib.optional pythonSupport "python";

  meta = with lib; {
    homepage = "https://github.com/google/or-tools";
    license = licenses.asl20;
    description = ''
      Google's software suite for combinatorial optimization.
    '';
    maintainers = with maintainers; [ andersk ];
    platforms = with platforms; linux ++ darwin;
  };
}
