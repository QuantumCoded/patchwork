{ config, lib, pkgs, ... }:
let
  inherit (lib)
    concatStringsSep
    hm
    literalExpression
    mapAttrsToList
    mdDoc
    mkIf
    mkOption
    types
    ;

  inherit (cfg.internal)
    numPatches
    patchCommand
    patchworkWatcher
    ;

  cfg = config.services.patchwork;
in
{
  imports = [ ./base.nix ];

  options.services.patchwork = {
    patches = mkOption {
      type = with types; attrsOf (either str (listOf str));
      default = {};
      example = literalExpression ''
        {
          ".config/some/file" = \'\'s/Value=.*/Value="my value"/\'\';

          ".config/some/other/file" = [
            \'\'s/Value1=.*/Value1="my value 1"/\'\'
            \'\'s/Value2=.*/Value2="my value 2"/\'\'
          ];
        }
      '';
      description = mdDoc ''
        An attrset of files and patches to apply. These patches should be idempotent.
      '';
    };
  };

  config = mkIf (cfg.enable && numPatches > 0) {
    systemd.user.services.patchwork = mkIf cfg.watchForModify {
      Unit.Description = "Patchwork entr watcher service";
      Install.WantedBy = [ "default.target" ];
      Service.ExecStart = ''
        ${patchworkWatcher}
      '';
    };

    home.activation = {
      patchwork = hm.dag.entryAfter [ "writeBoundary" ]
        (concatStringsSep "\n"
          (mapAttrsToList
            (file: patchVal: "${patchCommand file patchVal}")
            cfg.internal.patchesAbsolute));

      patchwork-restart-service = hm.dag.entryAfter [ "reloadSystemd" ]
        ''${pkgs.systemd}/bin/systemctl --user restart patchwork'';
    };
  };
}
