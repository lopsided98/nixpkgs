{
  lib,
  stdenv,
  fetchFromGitHub,
  gitUpdater,
  cmake,
  pkg-config,
  docutils,
  pandoc,
  libnl,
  udev,
  udevCheckHook,
  python3,
  perl,
  withManPages ? !stdenv.hostPlatform.isi686,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "rdma-core";
  version = "65.0";

  src = fetchFromGitHub {
    owner = "linux-rdma";
    repo = "rdma-core";
    rev = "v${finalAttrs.version}";
    hash = "sha256-cAaWVE6/JU8ezjx+XrxNI6Su6VKxb2Jxl29sxU/yepI=";
  };

  __structuredAttrs = true;
  strictDeps = true;

  outputs = [
    "out"
    "dev"
    "scripts"
  ]
  ++ lib.optionals withManPages [
    "man"
  ];

  nativeBuildInputs = [
    cmake
    pkg-config
    python3
    udevCheckHook
  ]
  ++ lib.optionals withManPages [
    docutils
    pandoc
  ];

  buildInputs = [
    libnl
    perl
    udev
  ];

  cmakeFlags = [
    "-DCMAKE_INSTALL_RUNDIR=/run"
    "-DCMAKE_INSTALL_SHAREDSTATEDIR=/var/lib"
    "-DSYSUSERS_DIR=${placeholder "out"}/lib/sysusers.d"
  ]
  ++ lib.optionals (!withManPages) [
    "-DNO_MAN_PAGES=1"
  ];

  postPatch = ''
    substituteInPlace srp_daemon/srp_daemon.sh.in \
      --replace /bin/rm rm
  ''
  # As of CMake 4.4.3, when cross-compiling, if find_package(Python) is called
  # with the Interpreter and Development components, the Python package must be for the host
  # platform. This is a regression in CMake 4.4.3, and this behavior is not intended to occur ThWe don't build the Python
  # bindings, and therefore only need Python at build time, so just remove the
  # Development component to avoid this problem.
  + lib.optionalString (stdenv.hostPlatform != stdenv.buildPlatform) ''
    substituteInPlace CMakeLists.txt \
      --replace-fail "OPTIONAL_COMPONENTS Development" ""
  '';

  postInstall = ''
    # cmake script is buggy, move file manually
    mkdir -p $scripts/${perl.libPrefix}
    mv $out/share/perl5/* $scripts/${perl.libPrefix}
  '';

  postFixup = ''
    for pls in ibfindnodesusing.pl ibidsverify.pl check_lft_balance.pl; do
      echo "wrapping $pls"
      substituteInPlace $out/bin/$pls \
        --replace-fail "${perl}/bin/perl" "${perl}/bin/perl -I $scripts/${perl.libPrefix}"
      moveToOutput bin/$pls "$scripts"
    done
  '';

  doInstallCheck = true;

  passthru.updateScript = gitUpdater {
    rev-prefix = "v";
  };

  outputChecks.out.disallowedRequisites = [
    perl
  ];

  meta = {
    description = "RDMA Core Userspace Libraries and Daemons";
    homepage = "https://github.com/linux-rdma/rdma-core";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
    badPlatforms = [ lib.systems.inspect.platformPatterns.isStatic ];
    maintainers = [ lib.maintainers.markuskowa ];
  };
})
