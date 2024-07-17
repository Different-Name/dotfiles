{
  config,
  lib,
  ...
}: let
  cfg = config.nix-files;
in {
  options.nix-files = {
    user = lib.mkOption {
      description = ''
        Username of the system user
      '';
      type = lib.types.str;
      example = lib.literalExample "nerowy";
      default = "different";
    };

    xDisplayScale = {
      enable = lib.mkOption {
        description = ''
          If enabled, fractional scaling will be passed to x applications
          through their respective environmental variables
        '';
        type = lib.types.bool;
        default = false;
      };

      value = lib.mkOption {
        description = ''
          Scaling value
        '';
        type = lib.types.str;
        default = "1";
      };
    };

    tools = {
      ephemeral = {
        enable = lib.mkOption {
          description = ''
            Enable ephemeral filesystem helper tools
          '';
          type = lib.types.bool;
          default = false;
        };

        exclude-paths = {
          home = lib.mkOption {
            description = ''
              List of home files / directories to exclude from fed & fedh
            '';
            type = lib.types.listOf lib.types.str;
            default = [];
          };

          root = lib.mkOption {
            description = ''
              List of files / directories to exclude from fed
            '';
            type = lib.types.listOf lib.types.str;
            default = [];
          };
        };
      };
    };
  };

  config = let
    inherit (config.nix-files) user;

    persistentStoragePaths = {
      home = config.home-manager.users.${user}.home.persistence;
      root = config.environment.persistence;
    };

    splitPath = paths: (
      lib.filter
      (s: builtins.typeOf s == "string" && s != "")
      (lib.concatMap (builtins.split "/") paths)
    );

    concatPaths = paths: let
      prefix = lib.optionalString (lib.hasPrefix "/" (lib.head paths)) "/";
      path = lib.concatStringsSep "/" (splitPath paths);
    in
      prefix + path;

    relativeToAbsHome = path: concatPaths ["/home/${user}" path];

    persisted-paths = {
      home = lib.flatten (map
        (
          persistentStoragePath: let
            persistentStorage = persistentStoragePaths.home.${persistentStoragePath};
          in
            map
            (
              relativePath: {
                path = relativeToAbsHome relativePath;
                persistPath = concatPaths [persistentStoragePath relativePath];
              }
            )
            (persistentStorage.files
              ++ persistentStorage.directories)
        )
        (lib.attrNames persistentStoragePaths.home));

      root = lib.flatten (map
        (
          persistentStoragePath: let
            persistentStorage = persistentStoragePaths.root.${persistentStoragePath};
          in
            map (
              path: {
                path = path;
                persistPath = concatPaths [persistentStoragePath path];
              }
            )
            ((map (file: file.file) persistentStorage.files)
              ++ (map (dir: dir.directory) persistentStorage.directories))
        )
        (lib.attrNames persistentStoragePaths.root));
    };
  in {
    environment.sessionVariables = lib.mkMerge [
      (lib.mkIf cfg.xDisplayScale.enable {
        STEAM_FORCE_DESKTOPUI_SCALING = cfg.xDisplayScale.value;
        GDK_SCALE = cfg.xDisplayScale.value;
      })
      (lib.mkIf cfg.tools.ephemeral.enable {
        EPHT_SEARCH_ROOT = "/";
        EPHT_SEARCH_HOME = "/home/${user}";
        EPHT_SEARCH_P_ROOT = lib.concatStringsSep ":" (lib.attrNames persistentStoragePaths.root);
        EPHT_SEARCH_P_HOME = lib.concatStringsSep ":" (lib.attrNames persistentStoragePaths.home);
        EPHT_EXCLUDE_ROOT = lib.concatStringsSep ":" (cfg.tools.ephemeral.exclude-paths.root ++ (map (n: n.path) persisted-paths.root));
        EPHT_EXCLUDE_HOME = lib.concatStringsSep ":" ((map relativeToAbsHome cfg.tools.ephemeral.exclude-paths.home) ++ (map (n: n.path) persisted-paths.home));
        EPHT_EXCLUDE_P_ROOT = lib.concatStringsSep ":" (map (path: path.persistPath) persisted-paths.root);
        EPHT_EXCLUDE_P_HOME = lib.concatStringsSep ":" (map (path: path.persistPath) persisted-paths.home);
      })
    ];
  };
}
