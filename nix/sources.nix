{ fetchurl, gcc_latest }:

rec {
  mesVersion = "0.27.1";

  mesTarball = fetchurl {
    url = "mirror://gnu/mes/mes-${mesVersion}.tar.gz";
    hash = "sha256-GDpA6kfqSfih470bnRLmdjdNZNY7x557wa59Zz398l0=";
  };

  gcc46Version = "4.6.4";

  gcc46Tarball = fetchurl {
    url = "mirror://gnu/gcc/gcc-${gcc46Version}/gcc-${gcc46Version}.tar.bz2";
    hash = "sha256-Na8Wr6C2evm46xXK+3bSvF9WhUBVJSL13CyI3UXZd+g=";
  };

  gcc46GmpTarball = fetchurl {
    url = "mirror://gnu/gmp/gmp-4.3.2.tar.bz2";
    hash = "sha256-k2FiwDEohsIVgQAreZMoKaoEjPr5k3xiZa6qFPHNF3U=";
  };

  gcc46MpfrTarball = fetchurl {
    url = "https://www.mpfr.org/mpfr-2.4.2/mpfr-2.4.2.tar.bz2";
    hash = "sha256-x+daCKjUnSCC5MruFZGgXRG51WJ1FOZ48C1moSS88ro=";
  };

  gcc46MpcTarball = fetchurl {
    url = "https://gcc.gnu.org/pub/gcc/infrastructure/mpc-0.8.1.tar.gz";
    hash = "sha256-5mRgN1clH9ijUoSCdkl6THm3+LIf2K7dXMBZijj+4+Q=";
  };

  gcc10Version = "10.4.0";

  gcc10Tarball = fetchurl {
    url = "mirror://gnu/gcc/gcc-${gcc10Version}/gcc-${gcc10Version}.tar.xz";
    hash = "sha256-ySl9W818tD89/C/tU4npSMkxL9li72pM5FXP+WPr5PE=";
  };

  gcc10GmpVersion = "6.2.1";

  gcc10GmpTarball = fetchurl {
    url = "mirror://gnu/gmp/gmp-${gcc10GmpVersion}.tar.xz";
    hash = "sha256-/UgpkSzd0S+EGBw0Ucx1K+IkZD6H+sSXtp7d2txJtPI=";
  };

  gccLatestVersion = gcc_latest.version;

  gccLatestTarball = fetchurl {
    url = "mirror://gnu/gcc/gcc-${gccLatestVersion}/gcc-${gccLatestVersion}.tar.xz";
    hash = "sha256-Q4/ZloJrDIJIWinaA6ctcdbjVBqD7HAt9Ccfb+Al0k4=";
  };

  gnuHelloVersion = "2.12.2";

  gnuHelloTarball = fetchurl {
    url = "mirror://gnu/hello/hello-${gnuHelloVersion}.tar.gz";
    hash = "sha256-WpqZbcKSzCTc9BHO6H6S9qrluNE72caBm0x6nc4IGKs=";
  };

  gccLatestGmpVersion = "6.3.0";

  gccLatestGmpTarball = fetchurl {
    url = "mirror://gnu/gmp/gmp-${gccLatestGmpVersion}.tar.xz";
    hash = "sha256-o8K4AgG4nmhhb0rTC8Zq7kknw85Q4zkpyoGdXENTiJg=";
  };

  gccModernMpfrVersion = "4.2.2";

  gccModernMpfrTarball = fetchurl {
    url = "mirror://gnu/mpfr/mpfr-${gccModernMpfrVersion}.tar.xz";
    hash = "sha256-tnugOD736KhWNzTi6InvXsPDuJigHQD6CmhprYHGzgE=";
  };

  gccModernMpcVersion = "1.3.1";

  gccModernMpcTarball = fetchurl {
    url = "mirror://gnu/mpc/mpc-${gccModernMpcVersion}.tar.gz";
    hash = "sha256-q2QkkvXPiCt0qgy3MM1BCoHtzb7IlRg86TDnBsHHWbg=";
  };

  gccModernIslVersion = "0.24";

  gccModernIslTarball = fetchurl {
    url = "https://gcc.gnu.org/pub/gcc/infrastructure/isl-${gccModernIslVersion}.tar.bz2";
    hash = "sha256-/PeN2WVsEOuM+fvV9ZoLawE4YgX+GTSzsoegoYmBRcA=";
  };

  gnumakeVersion = "4.4.1";

  gnumakeTarball = fetchurl {
    url = "mirror://gnu/make/make-${gnumakeVersion}.tar.gz";
    hash = "sha256-3Rb7HWe/q3mnL16DkHNcSePo5wtJRaFasfgd23hlj7M=";
  };

  gnupatchVersion = "2.5.9";

  gnupatchTarball = fetchurl {
    url = "mirror://gnu/patch/patch-${gnupatchVersion}.tar.gz";
    hash = "sha256-7LXGRp1zK88B1uwa/p5k8WaMq6W/2xA8KNf1N7o824o=";
  };

  coreutilsVersion = "5.0";
  coreutilsLiveBootstrap = "https://github.com/fosslinux/live-bootstrap/raw/a8752029f60217a5c41c548b16f5cdd2a1a0e0db/sysa/coreutils-${coreutilsVersion}";

  coreutilsTarball = fetchurl {
    url = "mirror://gnu/coreutils/coreutils-${coreutilsVersion}.tar.gz";
    hash = "sha256-wnznXj9iRV9PrPTz/VW8njh30KsdXAQmyU2haMw0mIM=";
  };

  coreutilsMakefile = fetchurl {
    url = "${coreutilsLiveBootstrap}/mk/main.mk";
    hash = "sha256-zdGb+WebOqRY5X1bQXqrzlJo4NEULVoz1Rm7zlgnT1o=";
  };

  coreutilsPatches = [
    (fetchurl {
      url = "${coreutilsLiveBootstrap}/patches/modechange.patch";
      hash = "sha256-RddxUzLzTo/xYNDzfnu2fSv820QQYqP70NJrwYsiqhM=";
    })
    (fetchurl {
      url = "${coreutilsLiveBootstrap}/patches/mbstate.patch";
      hash = "sha256-fo/C2F0NzlGtuV+iQwW9sr4TB1oH6V4I2bI/6jRg42c=";
    })
    (fetchurl {
      url = "${coreutilsLiveBootstrap}/patches/ls-strcmp.patch";
      hash = "sha256-5pZCTaMtkAKuU76/tB3leBXrJ3DS5LWY3WvgrsnPqFM=";
    })
    (fetchurl {
      url = "${coreutilsLiveBootstrap}/patches/touch-getdate.patch";
      hash = "sha256-qhISPP99SWV1GaOdKC8q19PfWVoQ2KI3ykfOTU/5o/U=";
    })
    (fetchurl {
      url = "${coreutilsLiveBootstrap}/patches/touch-dereference.patch";
      hash = "sha256-qjnadcdkb0TSk8xWv+pjmh32O+bMm2ec5x0JMEcufnI=";
    })
    (fetchurl {
      url = "${coreutilsLiveBootstrap}/patches/expr-strcmp.patch";
      hash = "sha256-SaVxnAzFoHLjT/95ly8Yhzxc6UnbO3H3xzyGqh0Nw6U=";
    })
    (fetchurl {
      url = "${coreutilsLiveBootstrap}/patches/sort-locale.patch";
      hash = "sha256-zEShwIcwdMa6b/jHEDJ16apLFgfaYf8M9d37W1GArC0=";
    })
    (fetchurl {
      url = "${coreutilsLiveBootstrap}/patches/uniq-fopen.patch";
      hash = "sha256-1w2zfx+Mw2cC4b9D0SR18pGc+326yLLJgEQm2j3URmM=";
    })
    ./patches/coreutils-hash-no-float.patch
  ];

  nyaccVersion = "1.09.1";

  nyaccTarball = fetchurl {
    url = "mirror://savannah/nyacc/nyacc-${nyaccVersion}.tar.gz";
    hash = "sha256-DsmuU34NlReBpQ3jx5KayXqFwdS16F5dUVQuN1ECJxc=";
  };
}
