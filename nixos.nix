{ config, lib, ... }:
let
  inherit (lib)
    concatStringsSep
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
          "/some/file" = \'\'s/Value=.*/Value="my value"/\'\';

          "/some/other/file" = [
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
    systemd.services.patchwork = mkIf cfg.watchForModify {
      description = "Patchwork entr watcher service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = ''
          ${patchworkWatcher}
        '';
      };
    };

    system.activationScripts.patchwork.text = concatStringsSep "\n"
      (mapAttrsToList
        (file: patchVal: patchCommand file patchVal)
        cfg.internal.patchesAbsolute);
  };
}
