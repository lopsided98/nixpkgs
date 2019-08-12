{ version, sha256 }:

{ stdenv, buildPackages, fetchurl, perl, xz, bash

# we are a dependency of gcc, this simplifies bootstraping
, interactive ? false, ncurses, procps, autoreconfHook, help2man
}:

with stdenv.lib;

stdenv.mkDerivation rec {
  name = "texinfo-${optionalString interactive "interactive-"}${version}";
  inherit version;

  src = fetchurl {
    url = "mirror://gnu/texinfo/texinfo-${version}.tar.xz";
    inherit sha256;
  };

  patches = [
    ./texinfo-cross.patch
  ] ++ optional (version == "6.5") ./perl.patch;

  # help2man tries to execute `--help` on the programs, which fails during cross-compilation
  preBuild = optionalString (stdenv.hostPlatform != stdenv.buildPlatform) ''
    for page in ${buildPackages.texinfo}/share/man/man1/*; do
      zcat "$page" > "man/$(basename $page .gz)"
    done
  '';

  # We need a native compiler to build makedoc when cross-compiling.
  depsBuildBuild = [ buildPackages.stdenv.cc ];

  nativeBuildInputs = [ perl autoreconfHook help2man ]
    ++ optionals stdenv.isSunOS [ gawk ]
    ++ optional interactive ncurses;

  buildInputs = [ xz.bin perl bash ]
    ++ optionals stdenv.isSunOS [ libiconv ]
    ++ optional interactive ncurses;

  configureFlags = [
    "PERL=${buildPackages.perl}/bin/perl"
  ] ++ optional stdenv.isSunOS "AWK=${buildPackages.gawk}/bin/awk"
    ++ optional (stdenv.hostPlatform != stdenv.buildPlatform) "--disable-perl-xs";

  installFlags = [ "TEXMF=$out/texmf-dist" ];
  installTargets = [ "install" "install-tex" ];

  postFixup = optionalString (stdenv.hostPlatform != stdenv.buildPlatform) ''
    # fixup broken shebangs
    sed -i -e 's!${buildPackages.perl}!${perl}!' \
      $out/bin/{pod2texi,texi2any,makeinfo}
  '';

  checkInputs = [ procps ];

  doCheck = interactive
    && !stdenv.isDarwin
    && !stdenv.isSunOS; # flaky

  meta = {
    homepage = https://www.gnu.org/software/texinfo/;
    description = "The GNU documentation system";
    license = licenses.gpl3Plus;
    platforms = platforms.all;
    maintainers = with maintainers; [ vrthra oxij ];

    longDescription = ''
      Texinfo is the official documentation format of the GNU project.
      It was invented by Richard Stallman and Bob Chassell many years
      ago, loosely based on Brian Reid's Scribe and other formatting
      languages of the time.  It is used by many non-GNU projects as
      well.

      Texinfo uses a single source file to produce output in a number
      of formats, both online and printed (dvi, html, info, pdf, xml,
      etc.).  This means that instead of writing different documents
      for online information and another for a printed manual, you
      need write only one document.  And when the work is revised, you
      need revise only that one document.  The Texinfo system is
      well-integrated with GNU Emacs.
    '';
    branch = version;
  };
}
