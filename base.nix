{ config, lib, pkgs, ... }:
let
  inherit (builtins)
    attrNames
    head
    isList
    length
    ;

  inherit (lib)
    concatStringsSep
    literalExpression
    mapAttrsToList
    mdDoc
    mkEnableOption
    mkOption
    types
    mapAttrs'
    nameValuePair
    ;

  inherit (pkgs)
    writeShellScript
    ;

  basePath = config.home.homeDirectory or "";

  backupSuffix = if cfg.backup then ".${cfg.backupSuffix}" else "";

  patchNames = attrNames cfg.internal.patchesAbsolute;

  patchCommand = file: patchVal:
    if isList patchVal then
      patchesWithSed file patchVal
    else
      patchWithSed file patchVal;

  sed = "${pkgs.gnused}/bin/sed";

  patchWithSed = file: patch:
    "[ -f '${file}' ] && ${sed} -i${backupSuffix} '${patch}' '${file}'";

  patchesWithSed = file: patches:
    concatStringsSep " " [
      "[ -f '${file}' ] && ${sed} -i${backupSuffix}"
      (concatStringsSep " " (map (patch: "-e '${patch}'") patches))
      file
    ];

  patchworkPatcher =
    let
      cases = concatStringsSep "\n"
        (mapAttrsToList
          (file: patchVal: "'${file}') ${patchCommand file patchVal};;")
          cfg.internal.patchesAbsolute);
    in
    writeShellScript "patchwork-patcher"
      ''
        echo Saw change to $1
        case $1 in
        ${cases}
        esac
      '';

    patchworkWatcher =
      let
        watchedFiles = map (file: "'${file}'") patchNames;
        printVals =
          if cfg.internal.numPatches == 1 then
            head watchedFiles
          else
            "{${concatStringsSep "," watchedFiles}}"; 
      in
      writeShellScript "patchwork-watcher"
      ''
        echo Watching files: ${concatStringsSep " " watchedFiles}
        printf '%s\n' ${printVals} |
          ${pkgs.entr}/bin/entr -np ${patchworkPatcher} /_
      '';

  cfg = config.services.patchwork;
in
{
  options.services.patchwork = {
    enable = mkEnableOption (mdDoc "patchwork");

    watchForModify = mkOption {
      type = types.bool;
      default = false;
      example = literalExpression "true";
      description = mdDoc ''
        Use entr running in a systemd serivce to re-apply the patches on file modification.
      '';
    };

    backup = mkOption {
      type = types.bool;
      default = true;
      example = literalExpression "false";
      description = mdDoc ''
        Whether to backup patched files when using sed.
      '';
    };

    backupSuffix = mkOption {
      type = types.str;
      default = "bak";
      description = mdDoc ''
        The extension to use for the backed up file.
      '';
    };

    internal = mkOption {
      type = types.attrs;
      default = {};
      internal = true;
      visible = false;
    };
  };

  config = {
    services.patchwork.internal = {
      inherit
        patchCommand
        patchworkWatcher
        ;

      numPatches = length patchNames;

      patchesAbsolute = mapAttrs'
        (file: patchVal:
          nameValuePair
            (toString (/. + basePath + ("/" + file)))
            patchVal)
        cfg.patches;
    };
  };
}
