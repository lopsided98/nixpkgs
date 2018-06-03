{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.uwsgi;

  uwsgi = pkgs.uwsgi.override {
    plugins = cfg.plugins;
  };

  buildCfg = name: c:
    let
      plugins =
        if any (n: !any (m: m == n) cfg.plugins) (c.plugins or [])
        then throw "`plugins` attribute in uWSGI configuration contains plugins not in config.services.uwsgi.plugins"
        else c.plugins;

      hasPython = v: filter (n: n == "python${v}") plugins != [];
      hasPython2 = hasPython "2";
      hasPython3 = hasPython "3";

      python =
        if hasPython2 && hasPython3 then
          throw "`plugins` attribute in uWSGI configuration shouldn't contain both python2 and python3"
        else if hasPython2 then uwsgi.python2
        else if hasPython3 then uwsgi.python3
        else null;

      pythonEnv = python.withPackages (c.pythonPackages or (self: []));

      uwsgiCfg = {
        uwsgi =
          if c.type or "normal" == "normal"
            then {
              inherit plugins;
              env = mapAttrsToList (name: value: "${name}=${value}") ({
                PATH = c.path + optionalString (python != null) ":${pythonEnv}/bin";
              } // c.env);
            } // optionalAttrs (python != null) {
              pyhome = pythonEnv;
            } // c.extraConfig
          else if c.type == "emperor"
            then {
              emperor = c.vassalsDir;
              vassals-include-before = buildCfg "vassals-default" (c // {
                type = "normal";
                extraConfig = c.vassalsConfig;
              });
            } // c.extraConfig
          else throw "`type` attribute in uWSGI configuration should be either 'normal' or 'emperor'";
      };

    in pkgs.writeText "${name}.json" (builtins.toJSON uwsgiCfg);

    commonOptions = {
      pythonPackages = mkOption {
        default = self: [];
        defaultText = "self: []";
        description = ''
          Python packages to make available to the uWSGI app. This
          option is ignored unless the <literal>python2</literal> or
          <literal>python3</literal> plugin is enabled. In emperor mode,
          these packages will be made available to all vassals.
        '';
        example = literalExample "self: with self; [ flask ]";
      };

      path = mkOption {
        type = types.listOf types.path;
        default = [];
        apply = ps: "${makeSearchPath "bin" ps}:${makeSearchPath "sbin" ps}";
        description = ''
          Packages added to the <envar>PATH</envar> environment variable.
          Both the <filename>bin</filename> and <filename>sbin</filename>
          subdirectories of each package are added. In emperor mode, these
          packages will be made available to all vassals.
        '';
      };

      env = mkOption {
        type = types.attrs;
        default = {};
        description = ''
          Environment variables to set. If the <envar>PATH</envar>
          variable is specified in this option, it will override the
          <literal>path</literal> option. In emperor mode, these variables
          will be inherited by all vassals.
        '';
        example = {
          APPLICATION_SETTINGS = "/var/lib/application.settings";
        };
      };

      extraConfig = mkOption {
        type = types.attrs;
        default = {};
        description = ''
          Extra configuration options for uWSGI. In emperor mode, these
          options will apply to the emperor configuration, not the vassals. Use
          <literal>vassalsConfig</literal> to apply default configuration
          to each vassal.

          This option can be used to override uWSGI options that
          were automatically set by higher level options such as
          <literal>pythonPackages</literal> or <literal>env</literal>.
        '';
      };
    };

in {

  options = {
    services.uwsgi = commonOptions // {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable uWSGI";
      };

      runDir = mkOption {
        type = types.path;
        default = "/run/uwsgi";
        description = "Where uWSGI communication sockets can live";
      };

      type = mkOption {
        type = types.enum [ "normal" "emperor" ];
        default = "normal";
        description = ''
          Controls the operating mode for uWSGI, which can be either
          <literal>normal</literal> or <literal>emperor</literal>. In
          <literal>normal</literal> mode, a single app can be configured. In
          <literal>emperor</literal> mode, multiple apps can be configured
          using the <literal>vassals</literal> option.
        '';
      };

      vassals = mkOption {
        type = types.attrsOf (types.submodule {
          options = commonOptions // {
            plugins = mkOption {
              type = types.listOf types.str;
              default = cfg.plugins;
              description = ''
                Plugins used by this vassal. Must be a subset of the
                top-level plugins.
              '';
            };
          };
        });
        default = {};
        example = literalExample ''
          {
            moin = {
              pythonPackages = self: with self; [ moinmoin ];
              extraConfig = '''
                socket = "''${config.services.uwsgi.runDir}/uwsgi.sock";
              '''
            };
          }
        '';
        description = ''
          In emperor mode, this option defines the vassals to spawn. This
          option is ignored in normal mode.
        '';
      };

      plugins = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Plugins used with uWSGI";
      };

      vassalsDir = mkOption {
        type = types.path;
        default = pkgs.linkFarm "vassals" (mapAttrsToList (name: c: {
          name = "${name}.json";
          path = buildCfg name c;
        }) cfg.vassals);
        description = ''
          Directory containing vassal configuration files. By default,
          this is populated by the <literal>vassals</literal> option. This
          option is ignored in normal mode.
        '';
      };

      vassalsConfig = mkOption {
         type = types.attrs;
         default = {};
         description = ''
           Extra configuration passed to each vassal, using the
           <literal>vassals-include-before</literal> uWSGI option. This
           option is ignored in normal mode.
         '';
      };

      user = mkOption {
        type = types.str;
        default = "uwsgi";
        description = "User account under which uWSGI runs.";
      };

      group = mkOption {
        type = types.str;
        default = "uwsgi";
        description = "Group account under which uWSGI runs.";
      };
    } // commonOptions;
  };

  config = mkIf cfg.enable {
    systemd.services.uwsgi = {
      wantedBy = [ "multi-user.target" ];
      preStart = ''
        mkdir -p ${cfg.runDir}
        chown ${cfg.user}:${cfg.group} ${cfg.runDir}
      '';
      serviceConfig = {
        Type = "notify";
        ExecStart = "${uwsgi}/bin/uwsgi --uid ${cfg.user} --gid ${cfg.group} --json ${buildCfg "server" cfg}";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        ExecStop = "${pkgs.coreutils}/bin/kill -INT $MAINPID";
        NotifyAccess = "main";
        KillSignal = "SIGQUIT";
      };
    };

    users.users = optionalAttrs (cfg.user == "uwsgi") (singleton
      { name = "uwsgi";
        group = cfg.group;
        uid = config.ids.uids.uwsgi;
      });

    users.groups = optionalAttrs (cfg.group == "uwsgi") (singleton
      { name = "uwsgi";
        gid = config.ids.gids.uwsgi;
      });
  };
}
